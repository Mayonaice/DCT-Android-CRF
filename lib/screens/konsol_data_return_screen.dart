import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/return_api_service.dart';
import '../services/profile_service.dart';
import '../models/return_data_model.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';
import 'edit_return_screen.dart';
import 'profile_menu_screen.dart';

class KonsolDataReturnPage extends StatefulWidget {
  const KonsolDataReturnPage({super.key});

  @override
  State<KonsolDataReturnPage> createState() => _KonsolDataReturnPageState();
}

class _KonsolDataReturnPageState extends State<KonsolDataReturnPage> with AutoLogoutMixin {
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  String searchQuery = '';
  String? typeReturn;
  final AuthService _authService = AuthService();
  final ReturnApiService _returnApiService = ReturnApiService();
  final ProfileService _profileService = ProfileService();
  String _userName = ''; 
  String _branchName = '';
  String _userId = '';
  String _branchCode = '';
  
  // List to store return data from API
  List<ReturnData> _returnDataList = [];
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Selected return data
  ReturnData? _selectedReturnData;
  
  // Scroll controller for horizontal alignment
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadUserData();
    _loadReturnData();
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
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }
  
  // Load return data from API
  Future<void> _loadReturnData() async {
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
      debugPrint('🔍 Fetching return data with BranchCode: $_branchCode');
      final returnData = await safeApiCall(() => _returnApiService.getReturnList(
        branchCode: _branchCode
      ));
      
      if (returnData != null) {
        setState(() {
          _returnDataList = returnData;
          _isLoading = false;
        });
        
        debugPrint('🔍 Loaded ${returnData.length} return data items');
        
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
        _errorMessage = 'Failed to load return data: $e';
        _isLoading = false;
      });
      debugPrint('Error loading return data: $e');
    }
  }
  
  // Filter return data based on date range
  List<ReturnData> _filteredData = [];
  
  void _filterAndUpdateData() {
    if (_returnDataList.isEmpty) {
      setState(() {
        _filteredData = [];
      });
      return;
    }
    
    final filtered = _returnDataList.where((data) {
      // Parse dateSTReturn date (konsisten dengan tampilan)
      if (data.dateSTReturn == null) return false;
      
      DateTime? returnDate;
      try {
        returnDate = DateTime.parse(data.dateSTReturn!);
      } catch (e) {
        return false;
      }
      
      // Check if date is within range
      final inRange = (returnDate.isAfter(fromDate.subtract(const Duration(days: 1))) || 
                      returnDate.isAtSameMomentAs(fromDate)) && 
                      (returnDate.isBefore(toDate.add(const Duration(days: 1))) || 
                      returnDate.isAtSameMomentAs(toDate));
      
      return inRange;
    }).toList();
    
    setState(() {
      _filteredData = filtered;
    });
  }
  
  List<ReturnData> get filteredReturnData {
    return _filteredData;
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
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
              _loadReturnData(); // Refresh data when clicked
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
          
          // Data Return - Active
          _buildNavTab(
            title: 'Data Return',
            isActive: true,
            isTablet: isTablet,
            onTap: () {
              // Already on this page
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
          
          // Data Pengurangan
          _buildNavTab(
            title: 'Data Pengurangan',
            isActive: false,
            isTablet: isTablet,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/konsol_data_pengurangan');
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
            'Data Return',
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),
        SizedBox(height: isTablet ? 16 : 12),
        
        // Tanggal filter row - make it scrollable
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
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
                _filterAndUpdateData();
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
                _filterAndUpdateData();
              }),
              
              SizedBox(width: isTablet ? 32 : 24),
              
              // Type Return filter
              Text(
                'Type Return',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
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
              
              // Type Return dropdown
              Container(
                width: isTablet ? 180 : 150,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: typeReturn,
                    hint: const Text('Select Type'),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (String? newValue) {
                      setState(() {
                        typeReturn = newValue;
                      });
                    },
                    items: <String>['Type 1', 'Type 2', 'Type 3']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
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
        if (picked != null) {
          onChanged(picked);
          // Explicitly call filter when date changes
          _filterAndUpdateData();
        }
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
      'Tanggal Return',
      'WSID',
      'Lokasi',
      'A1',
      'A2',
      'A5',
      'A10',
      'A20',
      'A50',
      'A75',
      'A100',
      'Total Lembar',
      'Total Value'
    ];

    // Calculate responsive column widths based on available width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - (isTablet ? 32.0 : 24.0); // Account for padding
    
    // Calculate base column width
    final baseColumnWidth = availableWidth / columns.length;
    
    // Adjust column widths proportionally
    Map<String, double> columnWidths = {};
    for (var column in columns) {
      if (column == 'Tanggal Return') {
        columnWidths[column] = baseColumnWidth * 1.3;
      } else if (column == 'WSID' || column == 'Lokasi') {
        columnWidths[column] = baseColumnWidth * 1.2;
      } else if (column == 'Total Lembar' || column == 'Total Value') {
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
            // Table Header - With horizontal scrolling
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _horizontalScrollController,
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
                  : filteredReturnData.isEmpty
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
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalScrollController,
                          child: SingleChildScrollView(
                            child: Column(
                              children: filteredReturnData.map((data) {
                                final isSelected = _selectedReturnData?.id == data.id;
                                
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedReturnData = data;
                                    });
                                  },
                                  child: Container(
                                    color: isSelected ? Colors.blue.shade50 : Colors.transparent,
                                    child: Row(
                                  children: [
                                    // Tanggal Return
                                    Container(
                                      width: columnWidths['Tanggal Return'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.dateSTReturn ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // WSID
                                    Container(
                                      width: columnWidths['WSID'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.atmCode ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Lokasi
                                    Container(
                                      width: columnWidths['Lokasi'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.name ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A1
                                    Container(
                                      width: columnWidths['A1'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a1?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A2
                                    Container(
                                      width: columnWidths['A2'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a2?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A5
                                    Container(
                                      width: columnWidths['A5'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a5?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A10
                                    Container(
                                      width: columnWidths['A10'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a10?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A20
                                    Container(
                                      width: columnWidths['A20'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a20?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A50
                                    Container(
                                      width: columnWidths['A50'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a50?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A75
                                    Container(
                                      width: columnWidths['A75'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a75?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // A100
                                    Container(
                                      width: columnWidths['A100'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.a100?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Total Lembar
                                    Container(
                                      width: columnWidths['Total Lembar'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          right: BorderSide(color: Colors.grey.shade300),
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        data.tQty?.toString() ?? '0',
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Total Value
                                    Container(
                                      width: columnWidths['Total Value'],
                                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: Colors.grey.shade300),
                                        ),
                                      ),
                                      child: Text(
                                        NumberFormat.currency(
                                          locale: 'id',
                                          symbol: '',
                                          decimalDigits: 0,
                                        ).format(data.tValue ?? 0),
                                        style: TextStyle(
                                          fontSize: isTablet ? 11 : 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isTablet) {
    return Container(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Edit Data button
          GestureDetector(
            onTap: _selectedReturnData != null 
              ? () {
                  // Navigate to edit page with selected data and refresh data on return
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditReturnScreen(
                        returnData: _selectedReturnData!,
                      ),
                    ),
                  ).then((result) {
                    // If returned with success result, refresh data
                    if (result == true) {
                      _loadReturnData();
                    }
                  });
                }
              : null,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: _selectedReturnData != null ? Colors.yellow.shade200 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(30),
                boxShadow: _selectedReturnData != null ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit,
                    size: isTablet ? 20 : 18,
                    color: _selectedReturnData != null ? Colors.black87 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Edit Data',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                      color: _selectedReturnData != null ? Colors.black87 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Total section
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Total Seluruh Lembar (Denom)',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: isTablet ? 12 : 8),
              
              // Denomination rows
              Row(
                children: [
                  _buildDenominationField(
                    'A100', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a100 ?? 0}' : '0'
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  _buildDenominationField(
                    'A10', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a10 ?? 0}' : '0'
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Row(
                children: [
                  _buildDenominationField(
                    'A75', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a75 ?? 0}' : '0'
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  _buildDenominationField(
                    'A5', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a5 ?? 0}' : '0'
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Row(
                children: [
                  _buildDenominationField(
                    'A50', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a50 ?? 0}' : '0'
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  _buildDenominationField(
                    'A2', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a2 ?? 0}' : '0'
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Row(
                children: [
                  _buildDenominationField(
                    'A20', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a20 ?? 0}' : '0'
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  _buildDenominationField(
                    'A1', 
                    isTablet,
                    value: _selectedReturnData != null ? '${_selectedReturnData!.a1 ?? 0}' : '0'
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 12 : 8),
              
              // Totals
              Row(
                children: [
                  Text(
                    'Total Lembar    :',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text(
                    _selectedReturnData != null ? '${_selectedReturnData!.tQty ?? 0}' : '0',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isTablet ? 8 : 6),
              Row(
                children: [
                  Text(
                    'Total Nominal :',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text(
                    _selectedReturnData != null 
                      ? 'Rp ${NumberFormat('#,###').format(_selectedReturnData!.tValue ?? 0)}'
                      : 'Rp 0',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDenominationField(String denom, bool isTablet, {String value = '0'}) {
    return Row(
      children: [
        SizedBox(
          width: isTablet ? 60 : 50,
          child: Text(
            denom,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          width: isTablet ? 100 : 80,
          height: isTablet ? 36 : 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
            color: Colors.white,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Lembar',
          style: TextStyle(
            fontSize: isTablet ? 14 : 12,
          ),
        ),
      ],
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