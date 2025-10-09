import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:device_info_plus/device_info_plus.dart'; // REMOVED - namespace conflict
import 'dart:io';
import '../services/device_service.dart';
import '../widgets/custom_modals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DeviceInfoScreen extends StatefulWidget {
  const DeviceInfoScreen({Key? key}) : super(key: key);

  @override
  State<DeviceInfoScreen> createState() => _DeviceInfoScreenState();
}

class _DeviceInfoScreenState extends State<DeviceInfoScreen> {
  String _deviceName = 'Xiaomi Tab 11';
  String _androidVersion = 'Android Versi 14';
  String _osVersion = 'HYPER OS 14';
  String _androidId = '1234Uas612343456';
  String _idCreationDate = 'Unknown';
  bool _isLoading = true;
  bool _isPersistent = false;

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _loadDeviceInfo();
  }

  // Helper method to detect if device is tablet
  bool _isTablet(BuildContext context) {
    final data = MediaQuery.of(context);
    final shortestSide = data.size.shortestSide;
    // Consider device as tablet if shortest side is >= 600dp
    return shortestSide >= 600;
  }

  Future<void> _loadDeviceInfo() async {
    try {
      // Get comprehensive device information using DeviceService
      final deviceInfo = await DeviceService.getDeviceInfo();
      print('🔍 Retrieved device info: $deviceInfo');
      
      // Check if the ID is persistent
      final prefs = await SharedPreferences.getInstance();
      final creationDate = prefs.getString(DeviceService.DEVICE_ID_CREATED_AT);
      final isPersistent = await DeviceService.hasStoredDeviceId();
      
      String formattedDate = 'Unknown';
      if (creationDate != null) {
        try {
          final date = DateTime.parse(creationDate);
          formattedDate = DateFormat('dd-MM-yyyy HH:mm:ss').format(date);
        } catch (e) {
          formattedDate = 'Invalid date';
        }
      }
      
      setState(() {
        // Use real device information from DeviceService
        _deviceName = '${deviceInfo['brand'] ?? 'Unknown'} ${deviceInfo['model'] ?? 'Device'}';
        _androidVersion = deviceInfo['platform'] == 'Web' 
            ? 'Web Browser' 
            : 'Android ${deviceInfo['androidVersion'] ?? Platform.operatingSystemVersion}';
        _osVersion = deviceInfo['platform'] == 'Web'
            ? 'Web Platform'
            : deviceInfo['buildId'] ?? deviceInfo['osVersion'] ?? Platform.operatingSystemVersion;
        _androidId = deviceInfo['deviceId'] ?? 'Unknown';
        _idCreationDate = formattedDate;
        _isPersistent = isPersistent;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error getting device info: $e');
    }
  }

  void _copyAndroidId() async {
    Clipboard.setData(ClipboardData(text: _androidId));
    await CustomModals.showSuccessModal(
      context: context,
      message: 'Android ID berhasil di Copy kedalam Clipboard !',
    );
  }
  
  Future<void> _resetDeviceId() async {
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: 'This will delete the stored device ID and generate a new one. '
               'This is for testing purposes only and may cause authentication issues.',
      confirmText: 'Reset',
      cancelText: 'Cancel',
    );
    
    if (confirmed) {
      setState(() {
        _isLoading = true;
      });
      
      await DeviceService.resetDeviceId();
      
      // Reload device info
      await _loadDeviceInfo();
      
      await CustomModals.showSuccessModal(
        context: context,
        message: 'Device ID has been reset',
      );
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
                           right: isSmallScreen ? 25 : 35, // Margin kanan diperbesar
                         ),
                         child: Row(
                      children: [
                        // Box putih - lebar dikurangi dari kanan
                        Container(
                          width: isSmallScreen ? screenSize.width * 0.50 : screenSize.width * 0.55, // Lebar dikurangi lebih banyak untuk mencegah overflow
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
                          child: _isLoading 
                            ? const Center(
                                child: CircularProgressIndicator(),
                              )
                            : SingleChildScrollView(
                                child: Padding(
                                  padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Main content with horizontal layout exactly like in image
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left side - Device Icon (Phone or Tablet)
                                          Container(
                                            width: isSmallScreen ? 130 : 160,
                                            height: isSmallScreen ? 200 : 240,
                                            child: Image.asset(
                                              _isTablet(context) 
                                                  ? 'assets/images/tablet.png'
                                                  : 'assets/images/PhoneIcon.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) {
                                                // Fallback to manual design if image fails to load
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.black,
                                                      width: 3,
                                                    ),
                                                    borderRadius: BorderRadius.circular(15),
                                                  ),
                                                  child: Container(
                                                    margin: const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius: BorderRadius.circular(11),
                                                    ),
                                                    child: Column(
                                                      children: [
                                                        // Top notch area
                                                        Container(
                                                          height: isSmallScreen ? 12 : 15,
                                                          margin: EdgeInsets.symmetric(
                                                            horizontal: isSmallScreen ? 15 : 18,
                                                            vertical: isSmallScreen ? 3 : 4,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.black,
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                        ),
                                                        // Screen area
                                                        Expanded(
                                                          child: Container(
                                                            margin: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.grey.shade300,
                                                              borderRadius: BorderRadius.circular(4),
                                                              border: Border.all(
                                                                color: Colors.grey.shade400,
                                                                width: 1,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          
                                          SizedBox(width: isSmallScreen ? 20 : 30),
                                          
                                          // Right side - All Device Information
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Device Name
                                                Text(
                                                  'Nama Device',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                Container(
                                                  height: 1,
                                                  width: double.infinity,
                                                  color: Colors.black,
                                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                                ),
                                                Text(
                                                  _deviceName,
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                
                                                SizedBox(height: isSmallScreen ? 20 : 25),
                                                
                                                // Android Version
                                                Text(
                                                  'Versi Android',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                Container(
                                                  height: 1,
                                                  width: double.infinity,
                                                  color: Colors.black,
                                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                                ),
                                                Text(
                                                  _androidVersion,
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                
                                                SizedBox(height: isSmallScreen ? 20 : 25),
                                                
                                                // OS Version
                                                Text(
                                                  'Versi OS',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                Container(
                                                  height: 1,
                                                  width: double.infinity,
                                                  color: Colors.black,
                                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                                ),
                                                Text(
                                                  _osVersion,
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                
                                                SizedBox(height: isSmallScreen ? 20 : 25),
                                                
                                                // Android ID with copy button
                                                Text(
                                                  'Android ID',
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 16 : 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                Container(
                                                  height: 1,
                                                  width: double.infinity,
                                                  color: Colors.black,
                                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
                                                ),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        _androidId,
                                                        style: TextStyle(
                                                          fontSize: isSmallScreen ? 14 : 18,
                                                          color: Colors.black,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    GestureDetector(
                                                      onTap: _copyAndroidId,
                                                      child: Container(
                                                        padding: const EdgeInsets.all(4),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade200,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(
                                                            color: Colors.grey.shade400,
                                                            width: 1,
                                                          ),
                                                        ),
                                                        child: Icon(
                                                          Icons.copy,
                                                          size: isSmallScreen ? 12 : 14,
                                                          color: Colors.grey.shade700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                
                                                SizedBox(height: isSmallScreen ? 10 : 15),
                                                
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ),
                        
                        // Gap kecil antara box putih dan box biru
                        SizedBox(width: isSmallScreen ? 1 : 2), // Gap dikurangi hingga hampir dempet
                        
                        // Box biru di sebelah kanan dengan celah sedikit - Responsif
                        Expanded(
                          flex: 0,
                          child: Container(
                            width: isSmallScreen ? 5 : 8, // Lebar box biru diperkecil hingga hampir dempet
                            constraints: BoxConstraints(
                              minHeight: 300, // Tinggi minimum sama dengan box putih
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xFFA9D0D7),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(25), // Border radius ditambah
                                bottomRight: Radius.circular(25),
                              ),
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
          // Navigation Buttons - Segmented control style
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30), // Border radius diperbesar
              // Removed background color to let individual buttons show their colors
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
                  isActive: false,
                  onTap: () => Navigator.of(context).pushReplacementNamed('/profile'),
                  isSmallScreen: isSmallScreen,
                  isMiddle: true,
                ),
                _buildNavButton(
                  title: 'Ponsel Saya',
                  isActive: true,
                  onTap: () {}, // Current page
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