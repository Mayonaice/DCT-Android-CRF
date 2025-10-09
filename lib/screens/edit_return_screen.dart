import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/return_data_model.dart';
import '../models/update_qty_catridge_request.dart';
import '../services/return_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/tl_supervisor_dialog.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';

class EditReturnScreen extends StatefulWidget {
  final ReturnData returnData;
  
  const EditReturnScreen({super.key, required this.returnData});

  @override
  State<EditReturnScreen> createState() => _EditReturnScreenState();
}

class _EditReturnScreenState extends State<EditReturnScreen> with AutoLogoutMixin {
  // Controllers for text fields
  final TextEditingController _a1Controller = TextEditingController();
  final TextEditingController _a2Controller = TextEditingController();
  final TextEditingController _a5Controller = TextEditingController();
  final TextEditingController _a10Controller = TextEditingController();
  final TextEditingController _a20Controller = TextEditingController();
  final TextEditingController _a50Controller = TextEditingController();
  final TextEditingController _a75Controller = TextEditingController();
  final TextEditingController _a100Controller = TextEditingController();
  
  // Total values
  int _totalLembar = 0;
  int _totalNominal = 0;
  
  // API services
  final ReturnApiService _returnApiService = ReturnApiService();
  final AuthService _authService = AuthService();
  
  // State variables
  bool _isSubmitting = false;
  String _errorMessage = '';
  String _successMessage = '';
  String _userNik = '';

  @override
  void initState() {
    super.initState();
    // Set landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Initialize controllers with data
    _a1Controller.text = '${widget.returnData.a1 ?? 0}';
    _a2Controller.text = '${widget.returnData.a2 ?? 0}';
    _a5Controller.text = '${widget.returnData.a5 ?? 0}';
    _a10Controller.text = '${widget.returnData.a10 ?? 0}';
    _a20Controller.text = '${widget.returnData.a20 ?? 0}';
    _a50Controller.text = '${widget.returnData.a50 ?? 0}';
    _a75Controller.text = '${widget.returnData.a75 ?? 0}';
    _a100Controller.text = '${widget.returnData.a100 ?? 0}';
    
    // Calculate initial totals
    _calculateTotals();
    
    // Load user data
    _loadUserData();
  }
  
  // Load user data from shared preferences
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          // Try multiple possible field names for NIK
          _userNik = userData['nik'] ?? 
                    userData['userID'] ?? 
                    userData['NIK'] ?? 
                    userData['UserID'] ?? 
                    userData['userId'] ?? 
                    userData['UserNIK'] ?? 
                    userData['userNIK'] ?? '';
        });
        debugPrint('🔍 User NIK loaded: $_userNik');
        debugPrint('🔍 User noMeja: ${userData['noMeja']}');
        debugPrint('🔍 Full user data: ${userData.toString()}');
        
        // Check if NIK is empty
        if (_userNik.isEmpty) {
          debugPrint('⚠️ WARNING: User NIK is empty! Checking all user data keys:');
          for (var key in userData.keys) {
            debugPrint('🔍 Key: $key = ${userData[key]}');
          }
        }
      } else {
        debugPrint('⚠️ User data is null!');
      }
    } catch (e) {
      debugPrint('❌ Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    _a1Controller.dispose();
    _a2Controller.dispose();
    _a5Controller.dispose();
    _a10Controller.dispose();
    _a20Controller.dispose();
    _a50Controller.dispose();
    _a75Controller.dispose();
    _a100Controller.dispose();
    
    // Reset orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    super.dispose();
  }
  
  // Format date to dd MMM yyyy format
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return 'N/A';
    }
    
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }
  
  // Calculate totals based on current values
  void _calculateTotals() {
    final a1 = int.tryParse(_a1Controller.text) ?? 0;
    final a2 = int.tryParse(_a2Controller.text) ?? 0;
    final a5 = int.tryParse(_a5Controller.text) ?? 0;
    final a10 = int.tryParse(_a10Controller.text) ?? 0;
    final a20 = int.tryParse(_a20Controller.text) ?? 0;
    final a50 = int.tryParse(_a50Controller.text) ?? 0;
    final a75 = int.tryParse(_a75Controller.text) ?? 0;
    final a100 = int.tryParse(_a100Controller.text) ?? 0;
    
    setState(() {
      _totalLembar = a1 + a2 + a5 + a10 + a20 + a50 + a75 + a100;
      _totalNominal = a1 * 1000 + a2 * 2000 + a5 * 5000 + a10 * 10000 + 
                     a20 * 20000 + a50 * 50000 + a75 * 75000 + a100 * 100000;
    });
  }

  // Show TL Supervisor validation dialog
  void _showTLSupervisorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TLSupervisorDialog(
        onValidate: _validateTLSupervisor,
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
  
  // Validate TL Supervisor credentials
  Future<void> _validateTLSupervisor(String nik, String password) async {
    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) return;
    
    try {
      final response = await safeApiCall(() => _returnApiService.validateTLSupervisor(nik, password));
      
      // Log the full response for debugging
      debugPrint('TL Supervisor validation response: $response');
      
      if (response != null && response['success'] == true) {
        // Close the dialog
        Navigator.of(context).pop();
        
        // Submit data with validated TL Supervisor
        _submitData(nik);
      } else {
        // Extract specific error message from the response
        String errorMessage = response?['message'] ?? 'Validasi gagal';
        
        // Check for specific validation errors from the SP
        if (response?['data'] != null) {
          final validationData = response?['data'];
          final validationStatus = validationData['validationStatus']?.toString().toUpperCase() ?? '';
          final specificError = validationData['errorMessage']?.toString() ?? '';
          
          if (specificError.isNotEmpty) {
            errorMessage = specificError;
          }
          
          if (validationStatus == 'FAILED') {
            if (specificError.contains('NIK tidak ditemukan')) {
              errorMessage = 'NIK TL Supervisor tidak ditemukan dalam sistem';
            } else if (specificError.contains('Password tidak sesuai')) {
              errorMessage = 'Password TL Supervisor tidak sesuai';
            } else if (specificError.contains('tidak memiliki role yang sesuai')) {
              errorMessage = 'User tidak memiliki role TL Supervisor';
            }
          }
        }
        
        // Show error in modal
        Navigator.of(context).pop(); // Close the dialog first
        
        // Show error modal
        await CustomModals.showFailedModal(
          context: context,
          message: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('Error validating TL Supervisor: $e');
      
      // Show error in modal
      Navigator.of(context).pop(); // Close the dialog first
      
      // Show error modal
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error: $e',
      );
    }
  }
  
  // Submit data to API
  Future<void> _submitData(String spvTLCode) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
      _successMessage = '';
    });
    
    try {
      // Get table code from shared preferences
      String tableCode = '';
      try {
        final userData = await _authService.getUserData();
        if (userData != null) {
          tableCode = userData['noMeja'] ?? '';
          debugPrint('🔍 Table code loaded: $tableCode');
          
          if (tableCode.isEmpty) {
            debugPrint('⚠️ WARNING: Table code is empty! Checking all user data keys:');
            for (var key in userData.keys) {
              debugPrint('🔍 Key: $key = ${userData[key]}');
            }
          }
        } else {
          debugPrint('⚠️ WARNING: User data is null when loading table code!');
        }
      } catch (e) {
        debugPrint('❌ Error loading table code: $e');
      }
      
      // Create request object
      final request = UpdateQtyCatridgeRequest(
        idTool: widget.returnData.id ?? '',
        a1: _a1Controller.text,
        a2: _a2Controller.text,
        a5: _a5Controller.text,
        a10: _a10Controller.text,
        a20: _a20Controller.text,
        a50: _a50Controller.text,
        a75: _a75Controller.text,
        a100: _a100Controller.text,
        user: _userNik,
        spvTLCode: spvTLCode,
        tableCode: tableCode, // Pass table code from login
      );
      
      // Log the request for debugging
      debugPrint('Submitting update request: ${request.toJson()}');
      
      // Call API
      final response = await _returnApiService.updateQtyCatridge(request);
      
      // Log the full response for debugging
      debugPrint('Update qty catridge response: $response');
      
      if (response['success'] == true) {
        setState(() {
          _successMessage = response['message'] ?? 'Data berhasil disimpan';
          _isSubmitting = false;
        });
        
        // Show success message
        await CustomModals.showSuccessModal(
          context: context,
          message: _successMessage,
          onPressed: () {
            Navigator.pop(context); // Close modal
            Navigator.of(context).pop(true); // Return true to indicate success
          },
        );
      } else {
        // Extract specific error message
        String errorMessage = response['message'] ?? 'Gagal menyimpan data';
        
        // Check for specific error codes
        if (response['errorCode'] != null) {
          final errorCode = response['errorCode'].toString();
          
          if (errorCode == 'SPVTL_REQUIRED') {
            errorMessage = 'Perlu validasi dari SPVTL terlebih dahulu';
          } else if (errorCode == 'INVALID_RETURN_ID') {
            errorMessage = 'ID Return tidak valid';
          } else if (errorCode == 'EOD_RESTRICTION') {
            errorMessage = 'Tidak bisa dilakukan pengeditan ketika bank sudah di EOD';
          }
        }
        
        setState(() {
          _errorMessage = errorMessage;
          _isSubmitting = false;
        });
        
        // Show error message
        await CustomModals.showFailedModal(
          context: context,
          message: _errorMessage,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isSubmitting = false;
      });
      
      // Show error message
      await CustomModals.showFailedModal(
        context: context,
        message: _errorMessage,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 768;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isTablet),
            if (_errorMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.red.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            if (_successMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                color: Colors.green.shade50,
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _successMessage,
                        style: TextStyle(color: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleSection(isTablet),
                    SizedBox(height: isTablet ? 16 : 12),
                    _buildInfoSection(isTablet),
                    SizedBox(height: isTablet ? 24 : 16),
                    _buildEditSection(isTablet),
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
          // Back button - Red triangle/arrow
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          
          // Title
          Text(
            'Kembali',
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.red,
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
                'JAKARTA-CIDENG',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Meja : 010101',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
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
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // User info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String userName = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        userName = snapshot.data!['userName'] ?? 
                                  snapshot.data!['name'] ?? 
                                  '';
                      }
                      return Text(
                        userName,
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String userId = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        userId = snapshot.data!['userId'] ?? 
                                snapshot.data!['userID'] ?? 
                                '';
                      }
                      return Text(
                        userId,
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
  
  Widget _buildTitleSection(bool isTablet) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.orange, width: 3),
        ),
      ),
      child: Text(
        'EDIT RETURN',
        style: TextStyle(
          fontSize: isTablet ? 24 : 20,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
    );
  }
  
  Widget _buildInfoSection(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WSID section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            widget.returnData.atmCode,
            style: TextStyle(
              fontSize: isTablet ? 20 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        SizedBox(height: isTablet ? 16 : 12),
        
        // Info row
        Row(
          children: [
            // Lokasi
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Lokasi',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.returnData.name,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tanggal Return
            Row(
              children: [
                Text(
                  'Tanggal Return',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ':',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(widget.returnData.dateSTReturn),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildEditSection(bool isTablet) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content with box
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Denom Awal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Text(
                          'Denom Awal (Lembar)',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Original values - show all denominations
                        _buildOriginalDenomRow('A100', '${widget.returnData.a100 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A75', '${widget.returnData.a75 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A50', '${widget.returnData.a50 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A20', '${widget.returnData.a20 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A10', '${widget.returnData.a10 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A5', '${widget.returnData.a5 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A2', '${widget.returnData.a2 ?? 0}', isTablet),
                        const SizedBox(height: 8),
                        _buildOriginalDenomRow('A1', '${widget.returnData.a1 ?? 0}', isTablet),
                        
                        // Totals
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            SizedBox(width: isTablet ? 100 : 80),
                            Text(
                              'Total Lembar',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${widget.returnData.tQty ?? 0}',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            SizedBox(width: isTablet ? 100 : 80),
                            Text(
                              'Total Nominal',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Rp ${NumberFormat('#,###').format(widget.returnData.tValue ?? 0)}',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Vertical divider
                  Container(
                    width: 1,
                    margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                    color: Colors.grey.shade300,
                  ),
                  
                    // Right column - Denom Edit
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                        Text(
                          'Denom Edit (Lembar)',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                          // Editable fields in two columns
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left column
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  _buildDenomEditField('A100', _a100Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A75', _a75Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A50', _a50Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A20', _a20Controller, isTablet),
                                ],
                              ),
                            ),
                            
                              // Right column
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                  _buildDenomEditField('A10', _a10Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A5', _a5Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A2', _a2Controller, isTablet),
                                  const SizedBox(height: 8),
                                  _buildDenomEditField('A1', _a1Controller, isTablet),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        // Totals
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              'Total Lembar',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$_totalLembar',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              'Total Nominal',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              ':',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Rp ${NumberFormat('#,###').format(_totalNominal)}',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
          
          // Submit button
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _isSubmitting ? null : _showTLSupervisorDialog,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 24,
                    vertical: isTablet ? 16 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: isTablet ? 24 : 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Submit Data',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildOriginalDenomRow(String denom, String value, bool isTablet) {
    return Row(
      children: [
        SizedBox(
          width: isTablet ? 60 : 50,
          child: Text(
            denom,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          ':',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Lembar',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
          ),
        ),
      ],
    );
  }
  
  Widget _buildDenomEditField(String denom, TextEditingController controller, bool isTablet) {
    return Row(
      children: [
        SizedBox(
          width: isTablet ? 60 : 50,
          child: Text(
            denom,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: isTablet ? 100 : 80,
          height: isTablet ? 40 : 36,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
            ),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 8),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _calculateTotals();
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Lembar',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
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