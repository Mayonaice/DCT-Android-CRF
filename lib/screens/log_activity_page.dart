import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/history_api_service.dart';
import '../models/history_model.dart';

class LogActivityPage extends StatefulWidget {
  const LogActivityPage({Key? key}) : super(key: key);

  @override
  State<LogActivityPage> createState() => _LogActivityPageState();
}

class _LogActivityPageState extends State<LogActivityPage>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final HistoryApiService _historyApiService = HistoryApiService();
  
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  List<HistoryItem> _prepareData = [];
  List<HistoryItem> _returnData = [];
  List<HistoryItem> _filteredPrepareData = [];
  List<HistoryItem> _filteredReturnData = [];
  
  bool _isLoadingPrepare = false;
  bool _isLoadingReturn = false;
  
  String _branchName = '';
  String _userName = '';
  String _userId = '';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserData();
    _loadHistoryData();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Load data based on current tab
      if (_tabController.index == 0) {
        // Prepare tab - reload prepare data
        _loadPrepareDataOnly();
      } else {
        // Return tab - reload return data
        _loadReturnDataOnly();
      }
    }
  }

  Future<void> _loadPrepareDataOnly() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        final branchCode = userData['groupId']?.toString() ?? userData['branchCode']?.toString() ?? '1';
        final userId = userData['userId']?.toString() ?? userData['nik']?.toString() ?? userData['id']?.toString() ?? '';
        await _loadPrepareData(branchCode, userId);
      }
    } catch (e) {
      debugPrint('Error loading prepare data: $e');
      _showErrorSnackBar('Failed to load prepare data: ${e.toString()}');
    }
  }

  Future<void> _loadReturnDataOnly() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        final branchCode = userData['groupId']?.toString() ?? userData['branchCode']?.toString() ?? '1';
        final userId = userData['userId']?.toString() ?? userData['nik']?.toString() ?? userData['id']?.toString() ?? '';
        await _loadReturnData(branchCode, userId);
      }
    } catch (e) {
      debugPrint('Error loading return data: $e');
      _showErrorSnackBar('Failed to load return data: ${e.toString()}');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _branchName = userData['branchName'] ?? userData['groupName'] ?? 'JAKARTA-CIDENG';
          _userName = userData['name'] ?? userData['userName'] ?? 'Lorenzo Putra';
          _userId = userData['userId']?.toString() ?? userData['nik']?.toString() ?? userData['id']?.toString() ?? '919081021';
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadHistoryData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        final branchCode = userData['groupId']?.toString() ?? userData['branchCode']?.toString() ?? '1';
        final userId = userData['userId']?.toString() ?? userData['nik']?.toString() ?? userData['id']?.toString() ?? '';
        
        // Load both prepare and return data simultaneously
        await Future.wait([
          _loadPrepareData(branchCode, userId),
          _loadReturnData(branchCode, userId),
        ]);
      }
    } catch (e) {
      debugPrint('Error loading history data: $e');
      _showErrorSnackBar('Failed to load history data: ${e.toString()}');
    }
  }

  Future<void> _loadPrepareData(String branchCode, String userId) async {
    setState(() {
      _isLoadingPrepare = true;
    });

    try {
      final response = await _historyApiService.getHistoryPrepare(
        branchCode: branchCode,
        userId: userId,
      );

      if (response.success) {
        setState(() {
          _prepareData = response.data;
          _filteredPrepareData = response.data;
        });
      } else {
        _showErrorSnackBar('Failed to load prepare history: ${response.message}');
      }
    } catch (e) {
      debugPrint('Error loading prepare data: $e');
      _showErrorSnackBar('Error loading prepare data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingPrepare = false;
      });
    }
  }

  Future<void> _loadReturnData(String branchCode, String userId) async {
    setState(() {
      _isLoadingReturn = true;
    });

    try {
      final response = await _historyApiService.getHistoryReturn(
        branchCode: branchCode,
        userId: userId,
      );

      if (response.success) {
        setState(() {
          _returnData = response.data;
          _filteredReturnData = response.data;
        });
      } else {
        _showErrorSnackBar('Failed to load return history: ${response.message}');
      }
    } catch (e) {
      debugPrint('Error loading return data: $e');
      _showErrorSnackBar('Error loading return data: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingReturn = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPrepareData = _prepareData;
        _filteredReturnData = _returnData;
      } else {
        _filteredPrepareData = _prepareData.where((item) {
          return item.id.toLowerCase().contains(query.toLowerCase()) ||
                 item.atmCode.toLowerCase().contains(query.toLowerCase()) ||
                 item.idTypeATM.toLowerCase().contains(query.toLowerCase());
        }).toList();
        _filteredReturnData = _returnData.where((item) {
          return item.id.toLowerCase().contains(query.toLowerCase()) ||
                 item.atmCode.toLowerCase().contains(query.toLowerCase()) ||
                 item.idTypeATM.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Widget _buildHeader() {
    final isTablet = MediaQuery.of(context).size.width >= 768;
    
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
            'Log Activity',
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
                child: Text(
                  'Meja: 010101',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // CRF_OPR button
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
              'CRF_OPR',
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
              _loadHistoryData();
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
                  Text(
                    _userId,
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
              SizedBox(width: isTablet ? 12 : 10),
              Container(
                width: isTablet ? 48 : 44,
                height: isTablet ? 48 : 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: const Color(0xFF10B981),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
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

  Widget _buildTabBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 24.0,
        vertical: isTablet ? 16.0 : 12.0,
      ),
      color: Colors.white,
      child: Row(
        children: [
          // Left spacer
          Expanded(flex: 1, child: Container()),
          
          // Center - Tab buttons with 1/3 screen width
          SizedBox(
            width: screenWidth / 3,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.grey[200],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: const Color(0xFF10B981),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.black54,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 16 : 14,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: isTablet ? 16 : 14,
                ),
                tabs: const [
                  Tab(text: 'Prepare'),
                  Tab(text: 'Return'),
                ],
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 24 : 16),
          
          // Right - Search form
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: isTablet ? 48 : 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterData,
                      decoration: InputDecoration(
                        hintText: 'Search',
                        hintStyle: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isTablet ? 16 : 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[600],
                          size: isTablet ? 24 : 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 12 : 8,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Container(
                  width: isTablet ? 48 : 40,
                  height: isTablet ? 48 : 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.search,
                    color: Colors.white,
                    size: isTablet ? 24 : 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(HistoryItem item) {
    // Format ATM Code to BCA-xxxx format
    String formattedAtmCode = item.atmCode.startsWith('BCA-') ? item.atmCode : 'BCA-${item.atmCode}';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
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
          // Header row with ID CRF and ATM Code
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ID CRF : ${item.id}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF8C00),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedAtmCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                  Text(
                    item.idTypeATM,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Data layout with 3 columns (kebawah)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Tanggal Return, Jam Mulai, Jam Selesai
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataRowInline('Tanggal Return', item.formattedDate),
                    const SizedBox(height: 4),
                    _buildDataRowInline('Jam Mulai', item.formattedStartTime),
                    const SizedBox(height: 4),
                    _buildDataRowInline('Jam Selesai', item.formattedFinishTime),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 2: Bank, Lokasi
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataRowInline('Bank', item.codeBank.isNotEmpty ? item.codeBank : 'Bank Central Asia'),
                    const SizedBox(height: 4),
                    _buildDataRowInline('Lokasi', item.lokasi.isNotEmpty ? item.lokasi : 'Jl. Bandung Raya No.1, Jawa Barat'),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 3: ATM Type, Total
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDataRowInline('ATM Type', item.idTypeATM.isNotEmpty ? item.idTypeATM : 'HYOSUNG Khusus B'),
                    const SizedBox(height: 4),
                    _buildDataRowInline('Total', 'Rp ${item.formattedTotal}'),
                  ],
                ),
              ),
            ],
          ),
          // Divider line
          const Divider(
            height: 24,
            thickness: 1,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            '$label :',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataRowLarge(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label :',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRowInline(String label, String value) {
    // Create padded label with consistent spacing
    String paddedLabel = '';
    if (label == 'Tanggal Return') {
      paddedLabel = 'Tanggal Return     ';
    } else if (label == 'Jam Mulai') {
      paddedLabel = 'Jam Mulai     ';
    } else if (label == 'Jam Selesai') {
      paddedLabel = 'Jam Finish    ';
    } else {
      paddedLabel = '$label     ';
    }
    
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$paddedLabel: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(List<HistoryItem> data, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
      );
    }

    // Use filtered data based on current tab
    List<HistoryItem> displayData = _tabController.index == 0 ? _filteredPrepareData : _filteredReturnData;
    
    if (displayData.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.history,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No history data available',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: displayData.length,
      itemBuilder: (context, index) {
        return _buildHistoryItem(displayData[index]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHistoryList(_filteredPrepareData, _isLoadingPrepare),
                _buildHistoryList(_filteredReturnData, _isLoadingReturn),
              ],
            ),
          ),
        ],
      ),
    );
  }
}