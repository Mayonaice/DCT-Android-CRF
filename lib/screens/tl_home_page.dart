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
import '../widgets/tl_header_widget.dart';
import '../screens/tl_approval_summary_screen.dart';
import '../screens/tl_prepare_confirmation_page.dart';
import '../screens/tl_return_confirmation_page.dart';
import 'dart:math' as math;

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

  int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  int _extractCount(dynamic payload, List<String> keys) {
    if (payload == null) return 0;
    if (payload is int || payload is double || payload is String) {
      return _asInt(payload);
    }

    if (payload is Map) {
      for (final key in keys) {
        if (payload.containsKey(key)) return _asInt(payload[key]);
      }
      if (payload.containsKey('count')) return _asInt(payload['count']);
      if (payload.containsKey('data')) return _extractCount(payload['data'], keys);
    }

    return 0;
  }

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
          'https://dev.advantagescm.com/LocalCRF/api/CRF/belumprepare?branchCode=$branchCode';
      
      print('🔍 TL HOME: Fetching belum prepare count from: $url');
      print('🔍 TL HOME: BranchCode parameter: $branchCode');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎯 TL HOME: Belum prepare response: $data');
        
        final count = _extractCount(data, const [
          'belumPrepare',
          'belum_prepare',
          'BelumPrepare',
          'BELUMPREPARE',
        ]);
        print('🎯 TL HOME: Belum prepare extracted count: $count');
        return count;
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
          'https://dev.advantagescm.com/LocalCRF/api/CRF/belumreturn?branchCode=$branchCode';
      
      print('🔍 TL HOME: Fetching belum return count from: $url');
      print('🔍 TL HOME: BranchCode parameter: $branchCode');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎯 TL HOME: Belum return response: $data');
        
        final count = _extractCount(data, const [
          'belumReturn',
          'belum_return',
          'BelumReturn',
          'BELUMRETURN',
        ]);
        print('🎯 TL HOME: Belum return extracted count: $count');
        return count;
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
  Future<bool> _loadCounts() async {
    if (_groupId == null) {
      print('🚨 TL HOME: No groupId available for loading counts');
      setState(() {
        _isLoadingCounts = false;
      });
      return false;
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
      return true;
    } catch (e) {
      print('🚨 TL HOME: Error loading counts: $e');
      setState(() {
        _isLoadingCounts = false;
      });
      return false;
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
                  TLHeaderWidget(
                    userName: _userName,
                    branchName: _branchName,
                    profileService: _profileService,
                  ),
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

  // Open QR scanner first (new flow)
  Future<void> _showFaceRecognition() async {
    debugPrint('🔄 [TL_APPROVAL] Starting new approval flow with QR scanner first...');
    
    // Start with QR scanner instead of face recognition
    await _openQRScanner();
  }

  // Show face verification widget (moved to after QR scan)
  Future<bool> _showFaceVerification() async {
    debugPrint('🎭 [FACE_VERIFICATION] Starting face verification...');
    
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
      return false;
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
      // Face verification successful, proceed to API calls
      debugPrint('✅ [FACE_VERIFICATION] Face verification successful');
      return true;
    } else {
      // Verification failed or cancelled
      debugPrint('❌ [FACE_VERIFICATION] Face verification failed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face verification failed. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
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

  // Process QR data and show summary page
  Future<void> _processQRDataAndCallAPIs(String qrData) async {
    if (_isProcessingQR) return;

    setState(() {
      _isProcessingQR = true;
    });

    try {
      debugPrint('🔍 [QR_PROCESS] Processing QR data...');
      debugPrint('🔍 [QR_PROCESS] QR data length: ${qrData.length}');
      
      final decryptedData = _authService.decryptDataFromQR(qrData);
      debugPrint('🔓 [QR_DECRYPT] Decrypted QR data: ${decryptedData.toString().substring(0, math.min(200, decryptedData.toString().length))}...');
      if (decryptedData == null) {
        throw Exception('Invalid QR data');
      }

      if (decryptedData.containsKey('simplified') && decryptedData['simplified'] == true) {
        final source = decryptedData['source']?.toString() ?? '';
        final qrIdTool = decryptedData['idTool']?.toString() ?? '';
        final cashierCode = decryptedData['cashierCode']?.toString() ?? '';
        final tableCode = decryptedData['tableCode']?.toString() ?? '';
        final totalNominal = int.tryParse(decryptedData['totalNominal']?.toString() ?? '');
        final totalLembar = int.tryParse(decryptedData['totalLembar']?.toString() ?? '');
        final jumlahKasetCatridge = int.tryParse(decryptedData['jumlahKasetCatridge']?.toString() ?? '');
        final wsid = decryptedData['wsid']?.toString();
        final bank = decryptedData['bank']?.toString();
        final lokasi = decryptedData['lokasi']?.toString();
        final atmType = decryptedData['atmType']?.toString();
        final jumlahKaset = int.tryParse(decryptedData['jumlahKaset']?.toString() ?? '');
        final action = source.toUpperCase() == 'RETURN' ? 'RETURN' : 'PREPARE';
        if (action == 'PREPARE') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TLPrepareConfirmationPage(
                idTool: qrIdTool,
                cashierCode: cashierCode,
                tableCode: tableCode,
                totalNominal: totalNominal,
                wsidFromQr: wsid,
                bankFromQr: bank,
                lokasiFromQr: lokasi,
                atmTypeFromQr: atmType,
                jumlahKasetFromQr: jumlahKaset,
              ),
            ),
          );
          return;
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TLReturnConfirmationPage(
                idTool: qrIdTool,
                cashierCode: cashierCode,
                tableCode: tableCode,
                totalNominal: totalNominal,
                totalLembar: totalLembar,
                jumlahKasetCatridge: jumlahKasetCatridge,
              ),
            ),
          );
          return;
        }
      }
      
      // Process full QR data with all information intact
      final action = decryptedData['action']?.toString() ?? '';
      final idTool = decryptedData['idTool']?.toString() ?? '';
      final username = decryptedData['username']?.toString() ?? '';
      final password = decryptedData['password']?.toString() ?? '';
      
      // Validate required fields
      if (action.isEmpty || idTool.isEmpty || username.isEmpty || password.isEmpty) {
        throw Exception('QR Code tidak lengkap. Data yang diperlukan: action, idTool, username, password');
      }
      
      // Check if this is a full data QR (with catridges and details)
      final hasCatridges = decryptedData.containsKey('catridges');
      final hasDetails = decryptedData.containsKey('details');
      
      if (hasCatridges && hasDetails) {
        // Full approval flow with complete data
        debugPrint('🔍 [QR_PROCESS] Processing full QR with catridges and details');
        
        // Validate catridges data
        final catridges = decryptedData['catridges'];
        if (catridges == null || (catridges is List && catridges.isEmpty)) {
          throw Exception('Data catridge tidak ditemukan dalam QR Code');
        }
        
        // Validate details data
        final details = decryptedData['details'];
        if (details == null) {
          throw Exception('Data details tidak ditemukan dalam QR Code');
        }
        
        // Show success message with full data info
        await CustomModals.showSuccessModal(
          context: context,
          message: 'QR Code berhasil diproses!\n\n'
              'Action: $action\n'
              'ATM: $idTool\n'
              'User: $username\n'
              'Catridges: ${catridges is List ? catridges.length : 'N/A'} items\n'
              'Details: Available',
        );
        
        debugPrint('🔍 [QR_PROCESS] Detected action: $action');
        return;
      } else {
        // Basic approval with essential data only
        debugPrint('🔍 [QR_PROCESS] Processing basic QR with essential data');
        
        await CustomModals.showSuccessModal(
          context: context,
          message: 'QR Code berhasil diproses!\n\n'
              'Action: $action\n'
              'ATM: $idTool\n'
              'User: $username\n'
              'Mode: Basic Approval',
        );
        
        debugPrint('🔍 [QR_PROCESS] Detected action: $action');
        return;
      }
      
      // Navigate to TL Approval Summary Screen only for full data QR
      if (hasCatridges && hasDetails) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TLApprovalSummaryScreen(
              qrData: decryptedData,
              userName: _userName,
              branchName: _branchName,
            ),
          ),
        );
        
        debugPrint('🔄 [QR_PROCESS] Returned from approval summary with result: $result');
      }
      
    } catch (e) {
      debugPrint('❌ [QR_PROCESS] Error processing QR data: $e');
      
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error processing QR code: ${e.toString()}',
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
