import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/konsol_api_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';
import 'profile_menu_screen.dart';

class KonsolModePage extends StatefulWidget {
  const KonsolModePage({super.key});

  @override
  State<KonsolModePage> createState() => _KonsolModePageState();
}

class _KonsolModePageState extends State<KonsolModePage> with AutoLogoutMixin {
  int selectedTabIndex = 0;
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String searchQuery = '';
  final AuthService _authService = AuthService();
  final KonsolApiService _konsolApiService = KonsolApiService();
  final ProfileService _profileService = ProfileService();
  String _userName = ''; 
  String _branchName = '';
  String _branchCode = '';
  String _userId = '';
  
  // List to store konsol data from API
  List<KonsolData> _konsolDataList = [];
  List<KonsolData> _filteredData = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Selected konsol data
  KonsolData? _selectedKonsolData;

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
          _branchCode = userData['groupId'] ?? userData['branchCode'] ?? '1'; // Menggunakan groupId
        });
        debugPrint('🔍 User data loaded - Branch Code: $_branchCode, UserName: $_userName, UserID: $_userId');
        _loadKonsolData(); // Load konsol data after user data is loaded
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  // Load konsol data from API
  Future<void> _loadKonsolData() async {
    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) return;
    
    // Pastikan user data sudah dimuat terlebih dahulu
    if (_branchCode.isEmpty) {
      await _loadUserData();
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Selalu gunakan branch code untuk filter data
      debugPrint('🔍 Fetching konsol data with BranchCode: $_branchCode');
      final konsolData = await safeApiCall(() => _konsolApiService.getKonsolAndroidList(
        branchCode: _branchCode
      ));
      
      if (konsolData != null) {
        setState(() {
          _konsolDataList = konsolData;
          _isLoading = false;
        });
        
        debugPrint('🔍 Loaded ${konsolData.length} konsol data items');
        
        // Debug: Print all timeStart values
        for (var item in konsolData) {
          debugPrint('🔍 Item ${item.id}: timeStart=${item.timeStart}');
        }
        
        // Filter data based on current date range
        _filterAndUpdateData();
      } else {
        setState(() {
          _errorMessage = 'Session expired. Please login again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load konsol data: $e';
        _isLoading = false;
      });
      debugPrint('Error loading konsol data: $e');
    }
  }
  
  // Filter konsol data based on date range
  void _filterAndUpdateData() {
    if (_konsolDataList.isEmpty) {
      setState(() {
        _filteredData = [];
      });
      debugPrint('🔍 Filter: No data in _konsolDataList');
      return;
    }
    
    debugPrint('🔍 Filter: Starting with ${_konsolDataList.length} items');
    
    final filtered = _konsolDataList.where((data) {
      // Parse TimeStart date
      if (data.timeStart == null) {
        debugPrint('🔍 Filter: Item ${data.id} has null timeStart');
        return false; // Skip items with null timeStart
      }
      
      DateTime? processDate;
      try {
        processDate = DateTime.parse(data.timeStart!);
        debugPrint('🔍 Filter: Parsed date for item ${data.id}: ${processDate.toString()}');
      } catch (e) {
        debugPrint('🔍 Filter: Failed to parse date for item ${data.id}: ${data.timeStart}');
        return false; // Skip items with invalid dates
      }
      
      // Check if date is within range
      final inRange = (processDate.isAfter(fromDate.subtract(const Duration(days: 1))) || 
                      processDate.isAtSameMomentAs(fromDate)) && 
                      (processDate.isBefore(toDate.add(const Duration(days: 1))) || 
                      processDate.isAtSameMomentAs(toDate));
      
      // Apply search filter if search query is not empty
      final searchMatch = searchQuery.isEmpty || 
                        (data.atmCode?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
                        (data.id?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
                        (data.name?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);
      
      final result = inRange && searchMatch;
      if (!result) {
        debugPrint('🔍 Filter: Item ${data.id} excluded. inRange=$inRange, searchMatch=$searchMatch');
      } else {
        debugPrint('🔍 Filter: Item ${data.id} included. inRange=$inRange, searchMatch=$searchMatch');
      }
      return result;
    }).toList();
    
    setState(() {
      _filteredData = filtered;
    });
    
    debugPrint('🔍 Filter: Finished with ${_filteredData.length} items');
    
    // No fallback - if filter doesn't match any items, show empty list
    debugPrint('🔍 Filter: Final filtered count: ${_filteredData.length}');
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 24.0 : 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDataKonsolSection(isTablet),
                      SizedBox(height: isTablet ? 24 : 20),
                      _buildDateRangeSection(isTablet),
                      SizedBox(height: isTablet ? 24 : 20),
                      _buildSearchSection(isTablet),
                      SizedBox(height: isTablet ? 24 : 20),
                      _buildDataTable(isTablet, screenHeight),
                      SizedBox(height: isTablet ? 24 : 20),
                      _buildBottomSections(isTablet, screenHeight),
                    ],
                  ),
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
              _loadKonsolData(); // Refresh data when clicked
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
                  final confirmed = await CustomModals.showConfirmationModal(
                    context: context,
                    message: "Apakah kamu yakin ingin pergi ke halaman profile?",
                    confirmText: "Ya",
                    cancelText: "Tidak",
                  );
                  if (confirmed) {
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
                          return Image(
                            image: snapshot.data!,
                            width: isTablet ? 48 : 44,
                            height: isTablet ? 48 : 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF10B981),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
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
    final tabs = ['Data Return', 'Data Konsol', 'Data Pengurangan', 'Data Closing'];
    
    return Container(
      height: isTablet ? 70 : 60,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32.0 : 24.0),
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
          SizedBox(width: isTablet ? 32 : 24),
          
          // Data Return tab
          _buildNavTab(
            title: 'Data Return',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_data_return');
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Konsol tab (active)
          _buildNavTab(
            title: 'Data Konsol',
            isActive: true,
            isTablet: isTablet,
            onTap: () {
              // Already on this page
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Pengurangan tab
          _buildNavTab(
            title: 'Data Pengurangan',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_data_pengurangan');
            },
          ),
          
          SizedBox(width: isTablet ? 12 : 8),
          
          // Data Closing tab
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
          horizontal: isTablet ? 24 : 20,
          vertical: isTablet ? 12 : 10,
        ),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFE5E7EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
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

  Widget _buildDataKonsolSection(bool isTablet) {
    return Container(
      padding: EdgeInsets.only(bottom: isTablet ? 8 : 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEA580C), width: 3),
        ),
      ),
      child: Text(
        'Data Konsol',
        style: TextStyle(
          fontSize: isTablet ? 24 : 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFEA580C),
        ),
      ),
    );
  }

  Widget _buildDateRangeSection(bool isTablet) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
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
          
          _buildDateField(fromDate, isTablet, (date) {
            setState(() => fromDate = date);
          }),
          
          SizedBox(width: isTablet ? 20 : 16),
          
          Text(
            'To',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          
          SizedBox(width: isTablet ? 20 : 16),
          
          _buildDateField(toDate, isTablet, (date) {
            setState(() => toDate = date);
          }),
          
          SizedBox(width: isTablet ? 20 : 16),
          
          ElevatedButton.icon(
            onPressed: _loadKonsolData,
            icon: Icon(Icons.refresh, size: isTablet ? 20 : 18),
            label: Text(
              'Refresh',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 10,
              ),
            ),
          ),
        ],
      ),
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
        if (picked != null) {
          onChanged(picked);
          // Explicitly call filter when date changes
          _filterAndUpdateData();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 12 : 10,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF9CA3AF)),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('dd MMM yyyy').format(date),
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            SizedBox(width: isTablet ? 12 : 8),
            Icon(
              Icons.calendar_today,
              size: isTablet ? 20 : 18,
              color: const Color(0xFF6B7280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection(bool isTablet) {
    return Row(
      children: [
        const Spacer(),
        Text(
          'Search',
          style: TextStyle(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
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
        Container(
          width: isTablet ? 250 : 200,
          height: isTablet ? 44 : 40,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9CA3AF)),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: TextField(
            onChanged: (value) {
              setState(() => searchQuery = value);
              _filterAndUpdateData();
            },
            style: TextStyle(fontSize: isTablet ? 16 : 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 10,
              ),
              suffixIcon: Icon(
                Icons.search,
                size: isTablet ? 22 : 20,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable(bool isTablet, double screenHeight) {
    final columns = [
      'ID Tool',
      'Tanggal Replenish',
      'Actual Replenish',
      'Tanggal Proses',
      'WSID',
      'A1',
      'A2',
      'A5',
      'A10',
      'A20',
      'A50',
      'A75',
      'A100',
      'QTY',
      'Value'
    ];

    // Calculate responsive column widths based on available width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (isTablet ? 32.0 : 24.0); // Account for padding
    
    // Calculate base column width
    final baseColumnWidth = availableWidth / columns.length;
    
    // Adjust column widths proportionally
    Map<String, double> columnWidths = {};
    for (var column in columns) {
      if (column == 'Tanggal Replenish' || column == 'Actual Replenish' || column == 'Tanggal Proses') {
        columnWidths[column] = baseColumnWidth * 1.3;
      } else if (column == 'WSID' || column == 'ID Tool') {
        columnWidths[column] = baseColumnWidth * 1.2;
      } else if (column == 'QTY' || column == 'Value') {
        columnWidths[column] = baseColumnWidth * 1.1;
      } else {
        columnWidths[column] = baseColumnWidth * 0.8;
      }
    }

    return Container(
      height: screenHeight * 0.4,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            // Table Header - With horizontal scrolling to prevent overflow
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
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
                      ),
                    )
                  : _filteredData.isEmpty
                    ? Center(
                        child: Text(
                          'No data available for selected date range',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                      : ListView.builder(
                          itemCount: _filteredData.length,
                          itemBuilder: (context, index) {
                            final data = _filteredData[index];
                            final isSelected = _selectedKonsolData?.id == data.id;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedKonsolData = data;
                                });
                              },
                              child: Container(
                                color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                                child: Row(
                                  children: columns.map((column) {
                                    String value = '';
                                    switch (column) {
                                      case 'ID Tool':
                                        value = data.id ?? '-';
                                        break;
                                      case 'Tanggal Replenish':
                                        if (data.dateReplenish != null) {
                                          try {
                                            final date = DateTime.parse(data.dateReplenish!);
                                            value = DateFormat('dd MMM yyyy').format(date);
                                          } catch (e) {
                                            value = 'Invalid';
                                          }
                                        } else {
                                          value = 'N/A';
                                        }
                                        break;
                                      case 'Actual Replenish':
                                        if (data.actualDateReplenish != null) {
                                          try {
                                            final date = DateTime.parse(data.actualDateReplenish!);
                                            value = DateFormat('dd MMM yyyy').format(date);
                                          } catch (e) {
                                            value = 'Invalid';
                                          }
                                        } else {
                                          value = 'N/A';
                                        }
                                        break;
                                      case 'Tanggal Proses':
                                        if (data.timeStart != null) {
                                          try {
                                            final date = DateTime.parse(data.timeStart!);
                                            value = DateFormat('dd MMM yyyy').format(date);
                                          } catch (e) {
                                            value = 'Invalid';
                                          }
                                        } else {
                                          value = 'N/A';
                                        }
                                        break;
                                      case 'WSID':
                                        value = data.atmCode ?? '-';
                                        break;
                                      case 'A1':
                                        value = '${data.a1Edit ?? 0}';
                                        break;
                                      case 'A2':
                                        value = '${data.a2Edit ?? 0}';
                                        break;
                                      case 'A5':
                                        value = '${data.a5Edit ?? 0}';
                                        break;
                                      case 'A10':
                                        value = '${data.a10Edit ?? 0}';
                                        break;
                                      case 'A20':
                                        value = '${data.a20Edit ?? 0}';
                                        break;
                                      case 'A50':
                                        value = '${data.a50Edit ?? 0}';
                                        break;
                                      case 'A75':
                                        value = '${data.a75Edit ?? 0}';
                                        break;
                                      case 'A100':
                                        value = '${data.a100Edit ?? 0}';
                                        break;
                                      case 'QTY':
                                        value = '${data.tQtyEdit ?? 0}';
                                        break;
                                      case 'Value':
                                        value = 'Rp ${NumberFormat('#,###').format(data.tValueEdit ?? 0)}';
                                        break;
                                    }
                                    
                                    return Container(
                                      width: columnWidths[column],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        value,
                                        style: TextStyle(
                                          fontSize: isTablet ? 12 : 9,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                                ),
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

  Widget _buildBottomSections(bool isTablet, double screenHeight) {
    return SizedBox(
      height: screenHeight * 0.3,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detail Sebelum section
          Expanded(
            child: Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Sebelum',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Expanded(child: _buildDetailTable(isTablet)),
                ],
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // Lokasi WSID section
          Expanded(
            child: Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1D5DB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lokasi WSID',
                    style: TextStyle(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Container(
                    height: screenHeight * 0.15,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(6),
                      color: const Color(0xFFF9FAFB),
                    ),
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    alignment: Alignment.centerLeft,
                    child: _selectedKonsolData == null
                        ? const Text(
                            'No data selected',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                            ),
                          )
                        : Text(
                            _selectedKonsolData!.name ?? 'N/A',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w500,
                              fontSize: isTablet ? 16 : 14,
                            ),
                            textAlign: TextAlign.left,
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

  Widget _buildDetailTable(bool isTablet) {
    final columns = ['ID Tool', 'A1', 'A2', 'A5', 'A10', 'A20', 'A50', 'A75', 'A100', 'QTY', 'Value'];
    
    // Calculate responsive column widths based on available width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = (screenWidth / 2) - (isTablet ? 70.0 : 50.0); // Account for padding and half width
    
    // Calculate base column width
    final baseColumnWidth = availableWidth / columns.length;
    
    // Adjust column widths proportionally
    Map<String, double> columnWidths = {};
    for (var column in columns) {
      if (column == 'ID Tool') {
        columnWidths[column] = baseColumnWidth * 1.2;
      } else if (column == 'QTY' || column == 'Value') {
        columnWidths[column] = baseColumnWidth * 1.1;
      } else {
        columnWidths[column] = baseColumnWidth * 0.9;
      }
    }
    
    return Column(
      children: [
        // Header
        Container(
          height: isTablet ? 40 : 35,
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            border: Border(
              top: BorderSide(color: Color(0xFFD1D5DB)),
              left: BorderSide(color: Color(0xFFD1D5DB)),
              right: BorderSide(color: Color(0xFFD1D5DB)),
              bottom: BorderSide(color: Color(0xFFD1D5DB)),
            ),
          ),
          child: Row(
            children: columns.map((column) {
              return Container(
                width: columnWidths[column],
                height: isTablet ? 40 : 35,
                padding: EdgeInsets.all(isTablet ? 4 : 2),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFD1D5DB)),
                  ),
                ),
                child: Center(
                  child: Text(
                    column,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 10 : 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        // Body
        Expanded(
          child: _selectedKonsolData == null
              ? const Center(
                  child: Text(
                    'No data selected',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontStyle: FontStyle.italic,
                      fontSize: 14,
                    ),
                  ),
                )
              : Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(6),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                      // ID Tool
                      Container(
                        width: columnWidths['ID Tool'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.id ?? 'N/A',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A1
                      Container(
                        width: columnWidths['A1'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a1Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A2
                      Container(
                        width: columnWidths['A2'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a2Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A5
                      Container(
                        width: columnWidths['A5'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a5Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A10
                      Container(
                        width: columnWidths['A10'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a10Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A20
                      Container(
                        width: columnWidths['A20'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a20Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A50
                      Container(
                        width: columnWidths['A50'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a50Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A75
                      Container(
                        width: columnWidths['A75'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a75Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // A100
                      Container(
                        width: columnWidths['A100'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _selectedKonsolData!.a100Default?.toString() ?? '0',
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // QTY - Calculate total from defaults
                      Container(
                        width: columnWidths['QTY'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: Color(0xFFD1D5DB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _calculateTotalQty(_selectedKonsolData!).toString(),
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      
                      // Value - Calculate total value from defaults
                      Container(
                        width: columnWidths['Value'],
                        padding: EdgeInsets.all(isTablet ? 4 : 2),
                        child: Center(
                          child: Text(
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: '',
                              decimalDigits: 0,
                            ).format(_calculateTotalValue(_selectedKonsolData!)),
                            style: TextStyle(
                              fontSize: isTablet ? 10 : 8,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
  
  // Helper method to calculate total quantity from default values
  int _calculateTotalQty(KonsolData data) {
    return (data.a1Default ?? 0) +
           (data.a2Default ?? 0) +
           (data.a5Default ?? 0) +
           (data.a10Default ?? 0) +
           (data.a20Default ?? 0) +
           (data.a50Default ?? 0) +
           (data.a75Default ?? 0) +
           (data.a100Default ?? 0);
  }
  
  // Helper method to calculate total value from default values
  int _calculateTotalValue(KonsolData data) {
    return (data.a1Default ?? 0) * 1000 +
           (data.a2Default ?? 0) * 2000 +
           (data.a5Default ?? 0) * 5000 +
           (data.a10Default ?? 0) * 10000 +
           (data.a20Default ?? 0) * 20000 +
           (data.a50Default ?? 0) * 50000 +
           (data.a75Default ?? 0) * 75000 +
           (data.a100Default ?? 0) * 100000;
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