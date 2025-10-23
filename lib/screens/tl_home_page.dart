import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/tl_qr_scanner_widget.dart';
import '../widgets/custom_modals.dart';
import '../widgets/face_recognition_widget.dart';

class TLHomePage extends StatefulWidget {
  const TLHomePage({super.key});

  @override
  State<TLHomePage> createState() => _TLHomePageState();
}

class _TLHomePageState extends State<TLHomePage> {
  int _selectedIndex = 1; // Default to middle tab (Approve TLSPV)
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final ApiService _apiService = ApiService();
  String _userName = '';
  String _branchName = '';
  String? _groupId; // Store groupId from user login
  bool _isProcessingQR = false;
  
  // State variables for dashboard counts
  int _belumPrepareCount = 0;
  int _belumReturnCount = 0;
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CRF_TL
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('DEBUG: TLHomePage initialized - portrait mode enforced');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      print('DEBUG: TLHomePage _loadUserData - userData: $userData');
      if (userData != null) {
        // Check role to confirm we're in the right place - prioritize roleID
        print('DEBUG: TLHomePage _loadUserData - all role fields:');
        print('DEBUG: roleID: ${userData['roleID']}');
        print('DEBUG: RoleID: ${userData['RoleID']}');
        print('DEBUG: role: ${userData['role']}');
        print('DEBUG: Role: ${userData['Role']}');
        
        final userRole = (userData['roleID'] ?? 
                         userData['RoleID'] ?? 
                         userData['role'] ?? 
                         userData['Role'] ?? 
                         userData['userRole'] ?? 
                         userData['UserRole'] ?? 
                         userData['position'] ?? 
                         userData['Position'] ?? 
                         '').toString().toUpperCase();
        print('DEBUG: TLHomePage _loadUserData - normalized userRole: $userRole');
        
        // Extract groupId for API calls
        String? groupId;
        if (userData.containsKey('groupId') &&
            userData['groupId'] != null &&
            userData['groupId'].toString().isNotEmpty) {
          groupId = userData['groupId'].toString();
        } else if (userData.containsKey('branchCode') &&
            userData['branchCode'] != null &&
            userData['branchCode'].toString().isNotEmpty) {
          groupId = userData['branchCode'].toString();
        } else if (userData.containsKey('BranchCode') &&
            userData['BranchCode'] != null &&
            userData['BranchCode'].toString().isNotEmpty) {
          groupId = userData['BranchCode'].toString();
        }
        
        setState(() {
          _userName = userData['userName'] ?? userData['userID'] ?? 'Lorenzo Putra';
          _branchName = userData['branchName'] ?? userData['branch'] ?? 'JAKARTA - CIDENG';
          _groupId = groupId;
        });
        
        print('🎯 TL HOME: Group ID for API calls: $_groupId');
        
        // Load dashboard counts after getting groupId
        if (_groupId != null) {
          _loadCounts();
        } else {
          print('🚨 TL HOME: No groupId available, using default values');
          setState(() {
            _isLoadingCounts = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoadingCounts = false;
      });
    }
  }

  // API method to fetch belum prepare count
  Future<int> _getBelumPrepareCount(String branchCode) async {
    try {
      final String url = 
          'http://10.10.0.223/LocalCRF/api/CRF/belumprepare?branchCode=$branchCode';
      
      print('🔍 TL HOME: Fetching belum prepare count from: $url');
      print('🔍 TL HOME: BranchCode parameter: $branchCode');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎯 TL HOME: Belum prepare response: $data');
        
        // Handle different response formats
        if (data is Map<String, dynamic> && data.containsKey('count')) {
          return data['count'] ?? 0;
        } else if (data is int) {
          return data;
        } else if (data is String) {
          return int.tryParse(data) ?? 0;
        }
        return 0;
      } else {
        print('🚨 TL HOME: Failed to fetch belum prepare count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('🚨 TL HOME: Error fetching belum prepare count: $e');
      return 0;
    }
  }

  // API method to fetch belum return count
  Future<int> _getBelumReturnCount(String branchCode) async {
    try {
      final String url = 
          'http://10.10.0.223/LocalCRF/api/CRF/belumreturn?branchCode=$branchCode';
      
      print('🔍 TL HOME: Fetching belum return count from: $url');
      print('🔍 TL HOME: BranchCode parameter: $branchCode');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎯 TL HOME: Belum return response: $data');
        
        // Handle different response formats
        if (data is Map<String, dynamic> && data.containsKey('count')) {
          return data['count'] ?? 0;
        } else if (data is int) {
          return data;
        } else if (data is String) {
          return int.tryParse(data) ?? 0;
        }
        return 0;
      } else {
        print('🚨 TL HOME: Failed to fetch belum return count: ${response.statusCode}');
        return 0;
      }
    } catch (e) {
      print('🚨 TL HOME: Error fetching belum return count: $e');
      return 0;
    }
  }

  // Method to load dashboard counts
  Future<void> _loadCounts() async {
    if (_groupId == null) {
      print('🚨 TL HOME: No groupId available for loading counts');
      setState(() {
        _isLoadingCounts = false;
      });
      return;
    }

    setState(() {
      _isLoadingCounts = true;
    });

    try {
      print('🔍 TL HOME: Loading counts with groupId: $_groupId');
      
      // Call both API endpoints concurrently
      final results = await Future.wait([
        _getBelumPrepareCount(_groupId!),
        _getBelumReturnCount(_groupId!),
      ]);

      setState(() {
        _belumPrepareCount = results[0];
        _belumReturnCount = results[1];
        _isLoadingCounts = false;
      });

      print('🎯 TL HOME: Counts loaded - Belum Prepare: $_belumPrepareCount, Belum Return: $_belumReturnCount');
    } catch (e) {
      print('🚨 TL HOME: Error loading counts: $e');
      setState(() {
        _isLoadingCounts = false;
      });
    }
  }

  // Method untuk refresh seluruh halaman
  Future<void> _onRefresh() async {
    print('🔄 TL HOME: Refreshing page data...');
    await _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: TLHomePage build method called - rendering TL home page');
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF4CAF50), // Green color to match theme
          backgroundColor: Colors.white,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(), // Memungkinkan scroll meski konten tidak penuh
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          kBottomNavigationBarHeight,
              ),
              child: Column(
                children: [
                  // Header Section
                  _buildHeader(),
                  const SizedBox(height: 16),
                  // Dashboard Section
                  _buildDashboard(),
                  // Add flexible spacer to fill remaining space
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Photo - smaller size
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: FutureBuilder<ImageProvider>(
                future: _profileService.getProfilePhoto(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Image(
                      image: snapshot.data!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[100],
                          child: Icon(
                            Icons.person,
                            size: 24,
                            color: Colors.grey[400],
                          ),
                        );
                      },
                    );
                  }
                  return Container(
                    color: Colors.grey[100],
                    child: Icon(
                      Icons.person,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Greeting and Name Section - more compact
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Plain greeting text without background
                const Text(
                  'Selamat Datang !',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                // User name with green background
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                // Branch location - smaller
                Text(
                  _branchName,
                  style: TextStyle(
                    fontSize: 13,
                    color: const Color.fromARGB(255, 29, 29, 29),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          // ADVANTAGE Logo - 3x larger size
          Container(
            width: 150, // 3x from 70
            height: 75, // 3x from 35
            child: Image.asset(
              'assets/images/adv-icon.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.blue[600],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Center(
                    child: Text(
                      'ADVANTAGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21, // 3x from 7
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFB3E5FC), // Light blue
            const Color(0xFF81D4FA), // Medium blue
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Important: fit content
        children: [
          // Dashboard Trip Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.2),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'Dashboard Trip',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Trip Counters
          Row(
            children: [
              // Belum Prepare
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Belum Prepare',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orange[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.list_alt,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _isLoadingCounts
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                  ),
                                )
                              : Text(
                                  '$_belumPrepareCount Trip',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Belum Return
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 0,
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Belum Return',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.orange[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.list_alt,
                              color: Colors.white,
                              size: 11,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _isLoadingCounts
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                                  ),
                                )
                              : Text(
                                  '$_belumReturnCount Trip',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Stack(
          clipBehavior: Clip.none, // Allow overflow beyond stack boundaries
          children: [
            // Background navigation items
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Ponsel Saya - Left side
                    Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: _buildNavItem(
                        icon: Icons.phone_android,
                        label: 'Ponsel Saya',
                        index: 0,
                        onTap: () {
                          Navigator.of(context).pushNamed('/tl_device_info');
                        },
                      ),
                    ),
                    // Profile - Right side
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: _buildNavItem(
                        icon: Icons.person,
                        label: 'Profile',
                        index: 2,
                        onTap: () {
                          Navigator.of(context).pushNamed('/tl_profile');
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Center Approve TLSPV Button - Reduced size for better proportion
            Positioned(
              left: 0,
              right: 0,
              top: -35, // Adjusted position for floating button
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    _showFaceRecognition();
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[800]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(35), // Perfect circle
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.black,
                          size: 50, // Increased from 36 to 50 (1.4x)
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Approve TLSPV',
                          style: TextStyle(
                            fontSize: 15, // Increased from 12 to 17 (1.4x)
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isCenter = false,
    VoidCallback? onTap,
  }) {
    final isSelected = _selectedIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        if (onTap != null) {
          onTap();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: isSelected ? Colors.black87 : Colors.grey[600],
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.black87 : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  // Open face verification before QR scanner
  Future<void> _showFaceRecognition() async {
    // Get current user ID
    final userData = await _authService.getUserData();
    final userId = userData?['userId'] ?? userData?['userID'] ?? '';
    
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Smart face recognition will handle photo loading and verification
    // Proceed directly with face verification using the smart ML Kit system
    await _showFaceVerification();
  }

  // Show face verification widget
  Future<void> _showFaceVerification() async {
    // Get user ID for face verification
    final userData = await _authService.getUserData();
    final userId = userData?['userId'] ?? userData?['userID'] ?? userData?['nik'] ?? '';
    
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User ID not found. Please login again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRecognitionWidget(
          personId: userId,
          onRecognitionComplete: (success, message) {
            Navigator.of(context).pop(success);
          },
        ),
      ),
    );

    if (result == true) {
      // Face verification successful, proceed to QR scanner
      _openQRScanner();
    } else {
      // Verification failed or cancelled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Open QR scanner directly without intermediate screen
  Future<void> _openQRScanner() async {
    // Set to portrait mode before scanning
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Use the QR scanner widget directly
    final String? qrResult = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => TLQRScannerWidget(
          title: 'Scan QR Code - TL Approval',
          onQRDetected: (code) {
            print('🔍 QR Code detected in TL scanner: ${code.length > 20 ? "${code.substring(0, 20)}..." : code}');
          },
          fieldKey: 'qrcode',
          fieldLabel: 'Approval QR',
        ),
      ),
    );
    
    // Reset orientation to portrait for this screen
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Process QR result if available
    if (qrResult != null && qrResult.isNotEmpty) {
      // Process QR data directly and call APIs
      _processQRDataAndCallAPIs(qrResult);
    }
  }

  // Process QR data and call planning/update and atm/catridge APIs
  Future<void> _processQRDataAndCallAPIs(String qrData) async {
    if (_isProcessingQR) return;

    setState(() {
      _isProcessingQR = true;
    });

    try {
      print('🔍 Processing QR data: ${qrData.length > 100 ? "${qrData.substring(0, 100)}..." : qrData}');
      
      // Parse QR JSON data
      final Map<String, dynamic> qrJson = json.decode(qrData);
      
      // Extract planning data
      final Map<String, dynamic>? planningData = qrJson['planning'];
      final List<dynamic>? catridgesData = qrJson['catridges'];
      
      if (planningData == null || catridgesData == null) {
        throw Exception('Invalid QR format: missing planning or catridges data');
      }

      // Get TL user data
      final userData = await _authService.getUserData();
      final tlUserId = userData?['userId'] ?? userData?['userID'] ?? '';
      
      if (tlUserId.isEmpty) {
        throw Exception('TL User ID not found. Please login again.');
      }

      // Show processing dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Processing QR approval...')
            ],
          ),
        ),
      );

      // Step 1: Call planning/update API
      print('=== STEP 1: UPDATE PLANNING ===');
      final planningRequest = Map<String, dynamic>.from(planningData);
      planningRequest['spvTLCode'] = tlUserId;
      planningRequest['isManual'] = 'N';
      
      print('Planning request: $planningRequest');
      
      final planningResponse = await _apiService.updatePlanning(
        idTool: planningRequest['idTool'],
        cashierCode: planningRequest['cashierCode'],
        spvTLCode: tlUserId,
        tableCode: planningRequest['tableCode'],
        warehouseCode: planningRequest['warehouseCode'],
      );
      
      if (!planningResponse.success) {
        throw Exception('Planning update failed: ${planningResponse.message}');
      }
      
      print('✅ Planning update successful');

      // Step 2: Call atm/catridge API for each catridge
      print('=== STEP 2: INSERT ATM CATRIDGES ===');
      
      for (int i = 0; i < catridgesData.length; i++) {
        final catridgeData = catridgesData[i] as Map<String, dynamic>;
        print('Processing catridge ${i + 1}/${catridgesData.length}: ${catridgeData['catridgeCode']}');
        
        final catridgeResponse = await _apiService.insertAtmCatridge(
          idTool: catridgeData['idTool'],
          bagCode: catridgeData['bagCode'] ?? '',
          catridgeCode: catridgeData['catridgeCode'] ?? '',
          sealCode: catridgeData['sealCode'] ?? '',
          catridgeSeal: catridgeData['catridgeSeal'] ?? '',
          denomCode: catridgeData['denomCode'] ?? '',
          qty: catridgeData['qty']?.toString() ?? '0',
          userInput: catridgeData['userInput'] ?? '',
          sealReturn: catridgeData['sealReturn'] ?? '',
          scanCatStatus: catridgeData['scanCatStatus'] ?? '',
          scanCatStatusRemark: catridgeData['scanCatStatusRemark'] ?? '',
          scanSealStatus: catridgeData['scanSealStatus'] ?? '',
          scanSealStatusRemark: catridgeData['scanSealStatusRemark'] ?? '',
          difCatAlasan: catridgeData['difCatAlasan'] ?? '',
          difCatRemark: catridgeData['difCatRemark'] ?? '',
        );
        
        if (!catridgeResponse.success) {
          throw Exception('Catridge ${i + 1} insert failed: ${catridgeResponse.message}');
        }
        
        print('✅ Catridge ${i + 1} inserted successfully');
      }

      // Close processing dialog
      Navigator.of(context).pop();

      // Show success message
      await CustomModals.showSuccessModal(
        context: context,
        message: 'QR approval completed successfully!\n\nPlanning updated and ${catridgesData.length} catridge(s) processed.',
      );

    } catch (e) {
      print('🚨 Error processing QR: $e');
      
      // Close processing dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      // Show error message
      await CustomModals.showFailedModal(
        context: context,
        message: 'QR processing failed:\n${e.toString()}',
      );
    } finally {
      setState(() {
        _isProcessingQR = false;
      });
    }
  }

  @override
  void dispose() {
    // Keep portrait orientation for CRF_TL when navigating away
    super.dispose();
  }
}