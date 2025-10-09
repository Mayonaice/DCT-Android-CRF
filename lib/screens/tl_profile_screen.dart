import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';
import '../screens/login_page.dart';

class TLProfileScreen extends StatefulWidget {
  const TLProfileScreen({Key? key}) : super(key: key);

  @override
  State<TLProfileScreen> createState() => _TLProfileScreenState();
}

class _TLProfileScreenState extends State<TLProfileScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  String _userName = '';
  String _userID = '';
  String _roleID = 'CRF_TL';
  String _branchName = '';
  final String _employeeAddress = 'Jl. Kebangsaan Timur 12 No.98, Sawah Panjang,\nJakarta Pusat, DKI Jakarta';

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CRF_TL
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? userData['userID'] ?? '';
          _userID = userData['userID'] ?? userData['userId'] ?? userData['nik'] ?? '';
          _roleID = userData['roleID'] ?? userData['role'] ?? 'CRF_TL';
          _branchName = userData['branchName'] ?? userData['branch'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _showLogoutDialog() async {
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: 'Apakah Anda yakin ingin keluar dari aplikasi?',
      confirmText: 'Logout',
      cancelText: 'Batal',
    );
    if (confirmed) {
      await _performLogout();
    }
  }

  Future<void> _performLogout() async {
    try {
      await _authService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomModals.showFailedModal(
          context: context,
          message: 'Error during logout: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header putih dengan tombol back merah dan title "Profile"
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Konten scrollable mengikuti layout gambar
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto profil di tengah atas (dari API)
                    Center(
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.shade400, width: 2),
                        ),
                        child: ClipOval(
                          child: FutureBuilder<ImageProvider>(
                            future: _profileService.getProfilePhoto(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                return Image(image: snapshot.data!, fit: BoxFit.cover);
                              }
                              return Container(
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.person, size: 72, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // userName
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 2, width: 180, color: Colors.black87),

                    const SizedBox(height: 16),

                    // userId
                    Text(
                      _userID,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 24),

                    // Role ID label
                    const Text(
                      'Role ID',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 2, width: 220, color: Colors.black54),

                    const SizedBox(height: 12),

                    // role value
                    Text(
                      _roleID,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 24),

                    // Branch label
                    const Text(
                      'Branch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 2, width: 260, color: Colors.black54),

                    const SizedBox(height: 12),

                    // branchname value
                    Text(
                      _branchName,
                      style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                    ),

                    const SizedBox(height: 48),

                    // Employee Address label
                    const Text(
                      'Employee Address :',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 2, width: 300, color: Colors.black54),

                    const SizedBox(height: 12),

                    // address value
                    Text(
                      _employeeAddress,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                    ),

                    const SizedBox(height: 40),

                    // Tombol Logout custom (pill, border merah, shadow)
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFE53935), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _showLogoutDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.power_settings_new, color: Color(0xFFE53935)),
                                SizedBox(width: 10),
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Color(0xFFE53935),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}