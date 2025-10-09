import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/konsol_api_service.dart';
import '../services/profile_service.dart';
import '../models/pengurangan_data_model.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';
import 'add_pengurangan_dialog.dart';
import 'profile_menu_screen.dart';

class KonsolDataPenguranganPage extends StatefulWidget {
  const KonsolDataPenguranganPage({super.key});

  @override
  State<KonsolDataPenguranganPage> createState() => _KonsolDataPenguranganPageState();
}

class _KonsolDataPenguranganPageState extends State<KonsolDataPenguranganPage> with AutoLogoutMixin {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String searchQuery = '';
  final AuthService _authService = AuthService();
  final KonsolApiService _konsolApiService = KonsolApiService();
  final ProfileService _profileService = ProfileService();
  String _userName = ''; 
  String _branchName = '';
  String _userId = '';
  String _branchCode = '';
  
  // Data state
  List<PenguranganData> _penguranganDataList = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadUserData();
  }

  // Load user data from login
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? userData['name'] ?? '';
          _userId = userData['userId'] ?? userData['userID'] ?? '';
          _branchName = userData['branchName'] ?? userData['branch'] ?? '';
          
          // Use groupId as the primary source for branchCode parameter
          _branchCode = userData['groupId'] ?? 
                       userData['GroupId'] ?? 
                       userData['groupID'] ?? 
                       userData['GroupID'] ?? 
                       userData['branchCode'] ?? 
                       userData['BranchCode'] ?? 
                       '';
        });
        debugPrint('🔍 User data loaded - UserName: $_userName, UserID: $_userId, GroupId/BranchCode: $_branchCode');
        
        // Debug: Print all user data keys and values
        userData.forEach((key, value) {
          debugPrint('🔍 UserData[$key] = $value');
        });
        
        // Load pengurangan data after user data is loaded
        _loadPenguranganData();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  // Format date for API
  String _formatDateForApi(DateTime date) {
    return DateFormat('dd-MM-yyyy').format(date);
  }
  
  // Load pengurangan data from API
  Future<void> _loadPenguranganData() async {
    if (_isLoading) return;
    
    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      final fromDateStr = _formatDateForApi(fromDate);
      final toDateStr = _formatDateForApi(toDate);
      
      // If branchCode (which is actually groupId) is empty, use a default value
      if (_branchCode.isEmpty) {
        debugPrint('⚠️ Warning: GroupId is empty! Using default value "1"');
        _branchCode = "1"; // Default group ID
      }
      
      debugPrint('🔍 Loading pengurangan data with parameters: groupId=$_branchCode, fromDate=$fromDateStr, toDate=$toDateStr');
      
      final data = await safeApiCall(() => _konsolApiService.getPenguranganAndroidList(
        branchCode: _branchCode, // This parameter name is still branchCode in the API service
        fromDate: fromDateStr,
        toDate: toDateStr,
      ));
      
      if (data != null) {
        setState(() {
          _penguranganDataList = data;
          _isLoading = false;
          
          // Filter by search query if provided
          if (searchQuery.isNotEmpty) {
            _filterDataBySearchQuery();
          }
        });
        
        debugPrint('🔍 Loaded ${data.length} pengurangan records');
      } else {
        setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
      }
      

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: ${e.toString()}';
      });
      debugPrint('🔍 Error loading pengurangan data: $e');
      
      // Show error in modal
      if (mounted) {
        CustomModals.showFailedModal(
          context: context,
          message: 'Gagal memuat data: ${e.toString()}',
        );
      }
    }
  }
  
  // Filter data by search query
  void _filterDataBySearchQuery() {
    if (searchQuery.isEmpty) return;
    
    final query = searchQuery.toLowerCase();
    setState(() {
      _penguranganDataList = _penguranganDataList.where((item) {
        return 
          (item.jenis?.toLowerCase().contains(query) ?? false) ||
          (item.bank?.toLowerCase().contains(query) ?? false) ||
          (item.mesin?.toLowerCase().contains(query) ?? false) ||
          (item.userInput?.toLowerCase().contains(query) ?? false) ||
          (item.keterangan?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
  
  // Show add pengurangan dialog
  Future<void> _showAddPenguranganDialog(BuildContext context, bool isTablet) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AddPenguranganDialog();
      },
    );
    
    // If dialog returns true, refresh data
    if (result == true) {
      // Show success message
      await CustomModals.showSuccessModal(
        context: context,
        message: 'Data berhasil ditambahkan',
      );
      
      // Refresh data
      _loadPenguranganData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isTablet),
            _buildNavigationTabs(isTablet),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFilterSection(isTablet),
                    SizedBox(height: isTablet ? 16 : 12),
                    _buildDataTable(isTablet, screenHeight),
                    SizedBox(height: isTablet ? 16 : 12),
                    _buildBottomSection(isTablet),
                  ],
                ),
              ),
            ),
            _buildFooter(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Container(
      height: isTablet ? 80 : 70,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 24.0,
        vertical: isTablet ? 16.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button - Green hamburger icon
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.menu,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          
          // Title
          Text(
            'Konsol Mode',
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          
          const Spacer(),
          
          // Location info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _branchName,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(
                width: isTablet ? 100 : 80,
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _authService.getUserData(),
                  builder: (context, snapshot) {
                    String meja = '';
                    if (snapshot.hasData && snapshot.data != null) {
                      meja = snapshot.data!['noMeja'] ?? 
                            snapshot.data!['NoMeja'] ?? 
                            '010101';
                    } else {
                      meja = '010101';
                    }
                    return Text(
                      'Meja: $meja',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    );
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // CRF_KONSOL button
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              'CRF_KONSOL',
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 16 : 12),
          
          // Refresh button
          GestureDetector(
            onTap: () {
              // Refresh data when clicked
              setState(() {
                fromDate = DateTime.now();
                toDate = DateTime.now();
                _loadUserData();
              });
            },
            child: Container(
              width: isTablet ? 44 : 40,
              height: isTablet ? 44 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // User info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: isTablet ? 150 : 120),
                    child: Text(
                      _userName,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String nik = '';
                      if (snapshot.hasData && snapshot.data != null) {
                                              nik = snapshot.data!['userId'] ?? 
                            snapshot.data!['userID'] ?? 
                            '';
                      } else {
                        nik = _userId;
                      }
                      return Text(
                        nik,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(width: isTablet ? 12 : 10),
              GestureDetector(
                onTap: () async {
                  final shouldNavigate = await CustomModals.showConfirmationModal(
                    context: context,
                    message: 'Apakah Anda ingin membuka halaman Profile Menu?',
                    confirmText: 'Ya',
                    cancelText: 'Tidak',
                  );
                  if (shouldNavigate == true) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileMenuScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  width: isTablet ? 48 : 44,
                  height: isTablet ? 48 : 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FutureBuilder<ImageProvider>(
                      future: _profileService.getProfilePhoto(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.hasData) {
                          return Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: snapshot.data!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            color: const Color(0xFF10B981),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTabs(bool isTablet) {
    return Container(
      height: isTablet ? 60 : 50,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 12.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Menu Lain :',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          
          // Data Return
          _buildNavTab(
            title: 'Data Return',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_data_return');
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Konsol
          _buildNavTab(
            title: 'Data Konsol',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_mode');
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Pengurangan - Active
          _buildNavTab(
            title: 'Data Pengurangan',
            isActive: true,
            isTablet: isTablet,
            onTap: () {
              // Already on this page
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Closing
          _buildNavTab(
            title: 'Data Closing',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_data_closing');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavTab({
    required String title,
    required bool isActive,
    required bool isTablet,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 16,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE5E7EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(
            color: const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.orange, width: 3),
            ),
          ),
          child: Text(
            'Data Pengurangan',
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        SizedBox(height: isTablet ? 16 : 12),
        
        // Tanggal filter row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left side - date filters
            Row(
              children: [
                // Tanggal label
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 8 : 6,
                    vertical: isTablet ? 4 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Tanggal',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                
                // From date
                _buildDateField(fromDate, isTablet, (date) {
                  setState(() => fromDate = date);
                  _loadPenguranganData(); // Auto-refresh when date changes
                }),
                
                SizedBox(width: isTablet ? 16 : 12),
                
                // To label
                Text(
                  'To',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                
                SizedBox(width: isTablet ? 16 : 12),
                
                // To date
                _buildDateField(toDate, isTablet, (date) {
                  setState(() => toDate = date);
                  _loadPenguranganData(); // Auto-refresh when date changes
                }),
              ],
            ),
            
            // Right side - search field
            Row(
              children: [
                Text(
                  'Search',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Container(
                  width: isTablet ? 200 : 160,
                  height: isTablet ? 40 : 36,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => searchQuery = value);
                      _filterDataBySearchQuery(); // Auto-filter when search query changes
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField(DateTime date, bool isTablet, Function(DateTime) onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 10,
          vertical: isTablet ? 8 : 6,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(date),
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_today,
              size: isTablet ? 18 : 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable(bool isTablet, double screenHeight) {
    final columns = [
      'Jenis',
      'Tanggal Replenish',
      'Tanggal Proses',
      'Bank',
      'Mesin',
      'A1',
      'A2',
      'A5',
      'A10',
      'A20',
      'A50',
      'A75',
      'A100',
      'User Input',
      'Keterangan'
    ];

    // Calculate responsive column widths based on available width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (isTablet ? 32.0 : 24.0); // Account for padding
    
    // Calculate base column width
    final baseColumnWidth = availableWidth / columns.length;
    
    // Adjust column widths proportionally
    Map<String, double> columnWidths = {};
    for (var column in columns) {
      if (column == 'Tanggal Replenish' || column == 'Tanggal Proses') {
        columnWidths[column] = baseColumnWidth * 1.3;
      } else if (column == 'Bank' || column == 'Mesin' || column == 'User Input') {
        columnWidths[column] = baseColumnWidth * 1.2;
      } else if (column == 'Keterangan') {
        columnWidths[column] = baseColumnWidth * 1.4;
      } else if (column == 'Jenis') {
        columnWidths[column] = baseColumnWidth * 1.0;
      } else {
        columnWidths[column] = baseColumnWidth * 0.7;
      }
    }

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            // Table Header - No horizontal scrolling
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: columns.map((column) {
                  return Container(
                    width: columnWidths[column],
                    padding: EdgeInsets.all(isTablet ? 8 : 4),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: Text(
                      column,
                      style: TextStyle(
                        fontSize: isTablet ? 12 : 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Table body with data or loading indicator
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty 
                  ? Center(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.red,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : _penguranganDataList.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _penguranganDataList.length,
                        itemBuilder: (context, index) {
                          final item = _penguranganDataList[index];
                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade300),
                              ),
                              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
                            ),
                            child: Row(
                              children: columns.map((column) {
                                String value = '';
                                switch (column) {
                                  case 'Jenis':
                                    value = item.jenis ?? '';
                                    break;
                                  case 'Tanggal Replenish':
                                    value = item.tanggalReplenish ?? '';
                                    break;
                                  case 'Tanggal Proses':
                                    value = item.tanggalProses ?? '';
                                    break;
                                  case 'Bank':
                                    value = item.bank ?? '';
                                    break;
                                  case 'Mesin':
                                    value = item.mesin ?? '';
                                    break;
                                  case 'A1':
                                    value = item.a1?.toString() ?? '0';
                                    break;
                                  case 'A2':
                                    value = item.a2?.toString() ?? '0';
                                    break;
                                  case 'A5':
                                    value = item.a5?.toString() ?? '0';
                                    break;
                                  case 'A10':
                                    value = item.a10?.toString() ?? '0';
                                    break;
                                  case 'A20':
                                    value = item.a20?.toString() ?? '0';
                                    break;
                                  case 'A50':
                                    value = item.a50?.toString() ?? '0';
                                    break;
                                  case 'A75':
                                    value = item.a75?.toString() ?? '0';
                                    break;
                                  case 'A100':
                                    value = item.a100?.toString() ?? '0';
                                    break;
                                  case 'User Input':
                                    value = item.userInput ?? '';
                                    break;
                                  case 'Keterangan':
                                    value = item.keterangan ?? '';
                                    break;
                                }
                                
                                return Container(
                                  width: columnWidths[column],
                                  padding: EdgeInsets.all(isTablet ? 8 : 4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      fontSize: isTablet ? 12 : 9,
                                    ),
                                    textAlign: column.contains('A') ? TextAlign.right : TextAlign.left,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isTablet) {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Add Data button
          GestureDetector(
            onTap: () => _showAddPenguranganDialog(context, isTablet),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add,
                    size: isTablet ? 20 : 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add Data',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isTablet) {
    return Container(
      height: isTablet ? 40 : 35,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
      color: Colors.white,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'CASH REPLENISH FORM  ver. 0.0.1',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}