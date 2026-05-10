import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/orientation_lock.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../services/konsol_api_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';
import 'profile_menu_screen.dart';

class KonsolDataClosingPage extends StatefulWidget {
  const KonsolDataClosingPage({super.key});

  @override
  State<KonsolDataClosingPage> createState() => _KonsolDataClosingPageState();
}

class _KonsolDataClosingPageState extends State<KonsolDataClosingPage> with WidgetsBindingObserver {
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
  bool _isLoadingClosing = false;
  String? _closingLoadError;
  List<ClosingAndroidListItem> _closingItems = [];
  Timer? _orientationLockTimer;
  bool _orientationEnforceScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceLandscapeOrientation();
    _startOrientationLockWatchdog();
    _loadUserData();
  }

  Future<void> _enforceLandscapeOrientation() async {
    if (!mounted) return;
    await OrientationLock.landscape();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceLandscapeOrientation();
    }
  }

  @override
  void didChangeMetrics() {
    _enforceLandscapeOrientation();
  }

  void _scheduleLandscapeEnforcement() {
    if (_orientationEnforceScheduled) return;
    _orientationEnforceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orientationEnforceScheduled = false;
      _enforceLandscapeOrientation();
    });
  }

  void _startOrientationLockWatchdog() {
    _orientationLockTimer?.cancel();
    _orientationLockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _enforceLandscapeOrientation();
    });
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
          _branchCode = (userData['groupId'] ??
                  userData['GroupId'] ??
                  userData['GroupID'] ??
                  userData['groupid'] ??
                  userData['groupID'] ??
                  userData['branchCode'] ??
                  userData['BranchCode'])
              ?.toString()
              .trim() ??
              '';
        });
        await _loadClosingData();
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  List<ClosingAndroidListItem> get _filteredClosingItems {
    final q = searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _closingItems;
    return _closingItems.where((item) {
      final haystack = [
        item.id,
        item.tanggalClosing,
        item.codeBank,
        item.jenisMesin,
        item.userClosing,
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _loadClosingData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingClosing = true;
      _closingLoadError = null;
    });

    try {
      final fromStr = DateFormat('dd-MM-yyyy').format(fromDate);
      final toStr = DateFormat('dd-MM-yyyy').format(toDate);
      debugPrint('🔍 Loading closing list: branchCode=$_branchCode, fromDate=$fromStr, toDate=$toStr, userId=$_userId');

      final data = await _konsolApiService.getClosingAndroidList(
        branchCode: _branchCode,
        fromDate: fromStr,
        toDate: toStr,
      );

      if (!mounted) return;
      setState(() {
        _closingItems = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _closingLoadError = e.toString();
      });
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal ambil data closing: ${e.toString()}',
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingClosing = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orientationLockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleLandscapeEnforcement();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(isTablet),
                _buildNavigationTabs(isTablet),
                Expanded(
                  child: GestureDetector(
                    onTap: () => FocusScope.of(context).unfocus(),
                    behavior: HitTestBehavior.translucent,
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
            if (_isLoadingClosing) ...[
              const ModalBarrier(
                dismissible: false,
                color: Color(0x66000000),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    final minHeight = isTablet ? 80.0 : 70.0;
    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
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
          // Menu button - Green hamburger icon (instead of back button)
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
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 200 : 160),
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
                    return Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Meja: $meja',
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF6B7280),
                          ),
                          maxLines: 1,
                        ),
                      ),
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
                // Reset any state variables that need refreshing
                fromDate = DateTime.now();
                toDate = DateTime.now();
                searchQuery = '';
              });
              // Re-load user data
              _loadUserData();
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
          
          // Data Closing - Active
          _buildNavTab(
            title: 'Data Closing',
            isActive: true,
            isTablet: isTablet,
            onTap: () {
              // Already on this page
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
            'Data Closing',
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
                    _loadClosingData();
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
                    _loadClosingData();
                  }),
                ],
              ),
            ),
            
            // Green Pengurangan button
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 20,
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF9FEEC3), // Light green background
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Pengurangan',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
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
                    onChanged: (value) => setState(() => searchQuery = value),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: InputBorder.none,
                      suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
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
      'ID Closing',
      'Tanggal Closing',
      'Code Bank',
      'Jenis Mesin',
      'A1',
      'A2',
      'A5',
      'A10',
      'A20',
      'A50',
      'A75',
      'A100',
      'User Closing'
    ];

    int columnFlex(String column) {
      if (column == 'Tanggal Closing') return 13;
      if (column == 'ID Closing' || column == 'Code Bank' || column == 'Jenis Mesin') return 12;
      if (column == 'User Closing') return 11;
      return 8;
    }

    final rows = _filteredClosingItems;

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
                children: columns.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final column = entry.value;
                  final isLast = idx == columns.length - 1;

                  return Expanded(
                    flex: columnFlex(column),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 8 : 4),
                      decoration: BoxDecoration(
                        border: Border(
                          right: isLast ? BorderSide.none : BorderSide(color: Colors.grey.shade300),
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
                    ),
                  );
                }).toList(),
              ),
            ),
            
            // Empty table body
            Expanded(
              child: _closingLoadError != null
                      ? Center(
                          child: Text(
                            _closingLoadError!,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.red.shade400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : rows.isEmpty
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
                              itemCount: rows.length,
                              itemBuilder: (context, index) {
                                final item = rows[index];
                                final values = <String, String?>{
                                  'ID Closing': item.id,
                                  'Tanggal Closing': item.tanggalClosing,
                                  'Code Bank': item.codeBank,
                                  'Jenis Mesin': item.jenisMesin,
                                  'A1': item.a1?.toString(),
                                  'A2': item.a2?.toString(),
                                  'A5': item.a5?.toString(),
                                  'A10': item.a10?.toString(),
                                  'A20': item.a20?.toString(),
                                  'A50': item.a50?.toString(),
                                  'A75': item.a75?.toString(),
                                  'A100': item.a100?.toString(),
                                  'User Closing': item.userClosing,
                                };

                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: columns.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final column = entry.value;
                                      final isLast = idx == columns.length - 1;

                                      return Expanded(
                                        flex: columnFlex(column),
                                        child: Container(
                                          padding: EdgeInsets.all(isTablet ? 8 : 4),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              right: isLast ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                                            ),
                                          ),
                                          child: Text(
                                            values[column] ?? '',
                                            style: TextStyle(fontSize: isTablet ? 12 : 9),
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                          ),
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
            onTap: () async {
              final result = await Navigator.pushNamed(context, '/konsol_data_closing_form');
              if (result == true) {
                await _loadClosingData();
              }
            },
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
