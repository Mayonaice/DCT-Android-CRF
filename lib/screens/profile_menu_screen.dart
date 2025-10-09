import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';

class ProfileMenuScreen extends StatefulWidget {
  const ProfileMenuScreen({Key? key}) : super(key: key);

  @override
  State<ProfileMenuScreen> createState() => _ProfileMenuScreenState();
}

class _ProfileMenuScreenState extends State<ProfileMenuScreen> {
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  String _userName = '';
  String _userID = '';
  String _roleID = '';
  String _branchName = '';
  final String _employeeAddress = 'Jl. Kebangsaan Timur 12 No.98, Sawah Panjang,\nJakarta Pusat, DKI Jakarta';

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? userData['userId'] ?? '';
          _userID = userData['userId'] ?? userData['userID'] ?? '';
          _roleID = userData['roleID'] ?? userData['role'] ?? '';
          _branchName = userData['branchName'] ?? userData['branch'] ?? '';
          // Employee address could be added to user data in the future
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        width: screenSize.width,
        height: screenSize.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg-deviceinfo.png'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Wrapper box untuk navbar dan box putih dengan warna #A9D0D7 - Responsif dengan Expanded
            Expanded(
              flex: 9, // Ambil 90% ruang yang tersedia
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: isSmallScreen ? screenSize.width * 0.60 : screenSize.width * 0.65,
                  constraints: BoxConstraints(
                    minHeight: 400, // Tinggi minimum untuk mencegah terlalu kecil
                    maxHeight: screenSize.height * 0.9, // Maksimum 90% tinggi layar
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFA9D0D7),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                child: Column(
                  children: [
                    // Top Navigation Bar
                    _buildTopNavigationBar(isSmallScreen),
                    
                    // Box putih dengan tinggi responsif
                     Expanded(
                       child: Container(
                         constraints: BoxConstraints(
                           minHeight: 300, // Tinggi minimum box putih
                         ),
                         margin: EdgeInsets.only(
                           top: 0, // Mepet dengan navbar
                           bottom: isSmallScreen ? 3 : 5, // Margin bottom diperkecil agar jarak hanya sedikit
                           right: isSmallScreen ? 25 : 35, // Margin kanan diperbesar seperti device_info
                         ),
                         child: Row(
                           children: [
                        // Box putih - lebar dikurangi dari kanan
                        Container(
                          width: isSmallScreen ? screenSize.width * 0.50 : screenSize.width * 0.55, // Lebar dikurangi seperti device_info
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(25), // Border radius ditambah
                              bottomRight: Radius.circular(25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 3,
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Main content with horizontal layout like in image
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Left side - Profile Photo (ukuran disesuaikan)
                                      Container(
                                        width: isSmallScreen ? 100 : 130,
                                        height: isSmallScreen ? 100 : 130,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 3,
                                          ),
                                        ),
                                        child: ClipOval(
                                          child: FutureBuilder<ImageProvider>(
                                            future: _profileService.getProfilePhoto(),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.done && 
                                                  snapshot.hasData) {
                                                return Image(
                                                  image: snapshot.data!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: Colors.grey.shade200,
                                                      child: Icon(
                                                        Icons.person,
                                                        size: isSmallScreen ? 50 : 65,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    );
                                                  },
                                                );
                                              } else {
                                                return Container(
                                                  color: Colors.grey.shade200,
                                                  child: Icon(
                                                    Icons.person,
                                                    size: isSmallScreen ? 50 : 65,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: isSmallScreen ? 20 : 30),
                                      
                                      // Right side - All Information in vertical layout
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Name - Large and bold
                                            Text(
                                              _userName,
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 22 : 28,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            
                                            // Long underline for name
                                            Container(
                                              height: 2,
                                              width: double.infinity,
                                              color: Colors.black,
                                              margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
                                            ),
                                            
                                            // User ID
                                            Text(
                                              _userID,
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 16 : 20,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            
                                            SizedBox(height: isSmallScreen ? 15 : 20),
                                            
                                            // Role ID Label
                                            Text(
                                              'Role ID',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 14 : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            
                                            // Underline for Role ID
                                            Container(
                                              height: 1,
                                              width: double.infinity,
                                              color: Colors.black,
                                              margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                            ),
                                            
                                            // Role ID Value
                                            Text(
                                              _roleID,
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 14 : 18,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            
                                            SizedBox(height: isSmallScreen ? 10 : 15),
                                            
                                            // Branch Label
                                            Text(
                                              'Branch',
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 14 : 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            
                                            // Underline for Branch
                                            Container(
                                              height: 1,
                                              width: double.infinity,
                                              color: Colors.black,
                                              margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                            ),
                                            
                                            // Branch Value
                                            Text(
                                              _branchName,
                                              style: TextStyle(
                                                fontSize: isSmallScreen ? 14 : 18,
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: isSmallScreen ? 15 : 20),
                                  
                                  // Employee Address Section (full width)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Employee Address :',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      
                                      // Underline for Address
                                      Container(
                                        height: 1,
                                        width: double.infinity,
                                        color: Colors.black,
                                        margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                      ),
                                      
                                      // Address Text (multi-line)
                                      Text(
                                        _employeeAddress,
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 12 : 16,
                                          color: Colors.black,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: isSmallScreen ? 20 : 25),
                                  
                                  // Logout Button - positioned to the left like in image
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: Colors.red, width: 2),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(20),
                                            onTap: () async {
                                              // Show confirmation dialog
                                              final shouldLogout = await CustomModals.showConfirmationModal(
                                                context: context,
                                                message: 'Apakah Anda yakin ingin keluar?',
                                                confirmText: 'Logout',
                                                cancelText: 'Batal',
                                              );
                                              
                                              if (shouldLogout == true) {
                                                await _authService.logout();
                                                if (mounted) {
                                                  Navigator.of(context).pushNamedAndRemoveUntil(
                                                    '/login',
                                                    (route) => false,
                                                  );
                                                }
                                              }
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isSmallScreen ? 15 : 20,
                                                vertical: isSmallScreen ? 8 : 12,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.power_settings_new,
                                                    color: Colors.red,
                                                    size: isSmallScreen ? 16 : 20,
                                                  ),
                                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                                  Text(
                                                    'Logout',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontSize: isSmallScreen ? 12 : 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(), // Push logout button to the left
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        // Gap kecil antara box putih dan box biru
                        SizedBox(width: isSmallScreen ? 4 : 6), // Gap dikurangi
                        
                        // Box biru di sebelah kanan dengan celah sedikit
                        Container(
                          width: isSmallScreen ? 30 : 40, // Lebar box biru dikurangi drastis
                          height: isSmallScreen ? 480 : 580, // Tinggi sama dengan box putih
                          decoration: const BoxDecoration(
                            color: Color(0xFFA9D0D7),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(25), // Border radius ditambah
                              bottomRight: Radius.circular(25),
                            ),
                          ),
                        ),
                        
                        // Sisa ruang kosong
                        Expanded(
                          child: Container(), // Kosong
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
                ),
              ),
            ),
            
            // Area kosong di bawah wrapper - Fleksibel menyusut
            Expanded(
              flex: 1, // Ambil 10% ruang yang tersedia, akan menyusut dulu
              child: Container(), // Area kosong untuk background
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavigationBar(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 25 : 40, // Padding diperbesar
        vertical: isSmallScreen ? 18 : 25, // Padding diperbesar
      ),
      child: Row(
        children: [
          // Navigation Buttons - Menyatu tanpa gap dengan warna baru
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30), // Border radius diperbesar
              color: const Color(0xFFD9D9D9), // Warna background navbar
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildNavButton(
                  title: 'Choose Menu',
                  isActive: false,
                  onTap: () => Navigator.of(context).pushReplacementNamed('/home'),
                  isSmallScreen: isSmallScreen,
                  isFirst: true,
                ),
                _buildNavButton(
                  title: 'Profile Menu',
                  isActive: true,
                  onTap: () {}, // Current page
                  isSmallScreen: isSmallScreen,
                  isMiddle: true,
                ),
                _buildNavButton(
                  title: 'Ponsel Saya',
                  isActive: false,
                  onTap: () => Navigator.of(context).pushReplacementNamed('/device_info'),
                  isSmallScreen: isSmallScreen,
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
    required bool isSmallScreen,
    bool isFirst = false,
    bool isMiddle = false,
    bool isLast = false,
  }) {
    BorderRadius borderRadius;
    if (isFirst) {
      borderRadius = const BorderRadius.only(
        topLeft: Radius.circular(30), // Border radius diperbesar
        bottomLeft: Radius.circular(30),
      );
    } else if (isLast) {
      borderRadius = const BorderRadius.only(
        topRight: Radius.circular(30), // Border radius diperbesar
        bottomRight: Radius.circular(30),
      );
    } else {
      borderRadius = BorderRadius.zero;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 20 : 30, // Padding diperbesar
          vertical: isSmallScreen ? 12 : 16, // Padding diperbesar
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF84DC64) : const Color(0xFFD9D9D9), // Hijau untuk aktif, abu-abu untuk nonaktif
          borderRadius: borderRadius,
          border: Border.all(
            color: Colors.black.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black, // Putih untuk aktif, hitam untuk nonaktif
            fontSize: isSmallScreen ? 14 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomContent(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(
        left: isSmallScreen ? 20 : 30, // Padding internal untuk konten
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'CASH REPLENISH FORM  ver. 0.0.1',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 12 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Image.asset(
                'assets/images/A50.png',
                height: isSmallScreen ? 25 : 35,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: isSmallScreen ? 25 : 35,
                    width: isSmallScreen ? 25 : 35,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              SizedBox(width: isSmallScreen ? 5 : 8),
              Text(
                'CRF',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isSmallScreen ? 16 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: isSmallScreen ? 2 : 4),
              Text(
                'Cash Replenish Form',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: isSmallScreen ? 10 : 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}