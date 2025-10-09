import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add clipboard import
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/return_model.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';
import 'dart:async'; // Import for Timer
import '../widgets/barcode_scanner_widget.dart'; // Fix barcode scanner import
import 'profile_menu_screen.dart';
import 'return_summary_page.dart';
// Add checkmark widget import

// CHECKMARK FIX: This file has been updated to fix the checkmark display issue.
// NEW APPROACH: Using stream-based barcode scanning for reliable checkmark validation
// Changes made:
// 1. Added stream listener for barcode results
// 2. Removed dependency on navigation return values
// 3. Direct state management for checkmark display
// 4. More reliable scanning validation system

void main() {
  runApp(const ReturnModeApp());
}

class ReturnModeApp extends StatelessWidget {
  const ReturnModeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Return Mode',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ReturnModePage(),
      debugShowCheckedModeBanner: false,
    );
  }




}

class ReturnModePage extends StatefulWidget {
  const ReturnModePage({Key? key}) : super(key: key);

  @override
  State<ReturnModePage> createState() => _ReturnModePageState();
}

class _ReturnModePageState extends State<ReturnModePage> with AutoLogoutMixin {
  final TextEditingController _idCRFController = TextEditingController();
  final ApiService _apiService = ApiService();
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  String _branchCode = '';
  String _errorMessage = '';
  bool _isLoading = false;
  
  // User data variables
  String _userName = '';
  String _branchName = '';
  String _userId = '';
  
  // Responsive design helper
  bool get isTablet => MediaQuery.of(context).size.width > 600;
  
  // State untuk data return dan detail header
  ReturnHeaderResponse? _returnHeaderResponse;
  Map<String, dynamic>? _userData;

  // References to cartridge sections - now using a list to handle dynamic sections
  final List<GlobalKey<_CartridgeSectionState>> _cartridgeSectionKeys = [];
  
  // New ID Tool controller for all sections
  final TextEditingController _idToolController = TextEditingController();
  
  // Add jamMulai controller
  final TextEditingController _jamMulaiController = TextEditingController();
  
  // Add tanggal replenish controller
  final TextEditingController _tanggalReplenishController = TextEditingController();
  
  // NEW: Controllers for detail return forms (read-only)
  final Map<String, TextEditingController> _detailReturnLembarControllers = {
    '100K': TextEditingController(),
    '75K': TextEditingController(),
    '50K': TextEditingController(),
    '20K': TextEditingController(),
    '10K': TextEditingController(),
    '5K': TextEditingController(),
    '2K': TextEditingController(),
    '1K': TextEditingController(),
  };
  
  final Map<String, TextEditingController> _detailReturnNominalControllers = {
    '100K': TextEditingController(),
    '75K': TextEditingController(),
    '50K': TextEditingController(),
    '20K': TextEditingController(),
    '10K': TextEditingController(),
    '5K': TextEditingController(),
    '2K': TextEditingController(),
    '1K': TextEditingController(),
  };
  
  // Timer for debouncing ID Tool typing
  Timer? _idToolTypingTimer;
  
  // TL approval controllers
  final TextEditingController _tlNikController = TextEditingController();
  final TextEditingController _tlPasswordController = TextEditingController();
  bool _isSubmitting = false;

  // NEW: Stream subscription for barcode results
  StreamSubscription<Map<String, dynamic>>? _barcodeStreamSubscription;

  // Helper method to get all bag codes from catridge data
  List<String> _getAllBagCodes() {
    if (_returnHeaderResponse?.data == null) return [];
    
    return _returnHeaderResponse!.data
        .map((catridge) => catridge.bagCode)
        .where((bagCode) => bagCode != null && bagCode.isNotEmpty)
        .cast<String>() // Cast to non-nullable String
        .toSet() // Remove duplicates
        .toList();
  }

  // Helper method to get all seal codes from catridge data
  List<String> _getAllSealCodes() {
    if (_returnHeaderResponse?.data == null) return [];
    
    return _returnHeaderResponse!.data
        .map((catridge) => catridge.sealCodeReturn)
        .where((sealCode) => sealCode != null && sealCode.isNotEmpty)
        .cast<String>() // Cast to non-nullable String
        .toSet() // Remove duplicates
        .toList();
  }

  // Build dropdown field widget
  Widget _buildDropdownField(
    String label,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged,
    {bool isValid = true, String errorText = ''}
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label with underline
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dropdown field
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isValid ? Colors.grey : Colors.red,
                width: 1,
              ),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedValue,
              hint: Text('Pilih $label'),
              isExpanded: true,
              items: items.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        // Error text
        if (!isValid && errorText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    
    // Initialize detail return controllers with empty values
    _detailReturnLembarControllers.forEach((key, controller) {
      controller.text = '0';
    });
    _detailReturnNominalControllers.forEach((key, controller) {
      controller.text = _formatCurrency(0);
    });
    
    _loadUserData();
    _setupBarcodeStream();
  }

  // TESTING PHASE 1: Disable barcode stream completely
  void _setupBarcodeStream() {
    // Barcode stream disabled during testing
    debugPrint('Barcode stream disabled for testing phase');
  }

  @override
  void dispose() {
    _idCRFController.dispose();
    _tlNikController.dispose();
    _tlPasswordController.dispose();
    _idToolController.dispose();
    _jamMulaiController.dispose();
    _tanggalReplenishController.dispose();
    
    // Dispose detail return controllers
    for (var controller in _detailReturnLembarControllers.values) {
      controller.dispose();
    }
    for (var controller in _detailReturnNominalControllers.values) {
      controller.dispose();
    }
    
    _barcodeStreamSubscription?.cancel(); // Cancel stream subscription
    if (_idToolTypingTimer != null) {
      _idToolTypingTimer!.cancel();
    }
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      setState(() {
        if (userData != null) {
          _userData = userData;
          
          // Extract user data
          _userName = userData['userName'] ?? userData['name'] ?? '';
          _userId = userData['userId'] ?? userData['userID'] ?? '';
          _branchName = userData['branchName'] ?? userData['branch'] ?? '';
          
          // Log all user data for debugging
          print('DEBUG - Loading user data: $userData');
          print('DEBUG - User data keys: ${userData.keys.toList()}');
          print('DEBUG - UserName: $_userName, UserID: $_userId, BranchName: $_branchName');
          
          // Extract and log the NIK value for debugging
          String userNIK = '';
          if (userData.containsKey('nik')) {
            userNIK = userData['nik'].toString();
          } else if (userData.containsKey('NIK')) {
            userNIK = userData['NIK'].toString();
          } else if (userData.containsKey('userId')) {
            userNIK = userData['userId'].toString();
          } else if (userData.containsKey('userID')) {
            userNIK = userData['userID'].toString();
          } else if (userData.containsKey('id')) {
            userNIK = userData['id'].toString();
          } else if (userData.containsKey('ID')) {
            userNIK = userData['ID'].toString();
          } else if (userData.containsKey('userName')) {
            userNIK = userData['userName'].toString();
          }
          print('DEBUG - Found NIK: $userNIK');
          
          // Ensure NIK exists in userData map
          if (userNIK.isNotEmpty && !userData.containsKey('nik')) {
            userData['nik'] = userNIK;
            print('DEBUG - Added NIK to userData: ${userData['nik']}');
          }
          
          // First try to get branchCode directly
          if (userData.containsKey('branchCode') && userData['branchCode'] != null && userData['branchCode'].toString().isNotEmpty) {
            _branchCode = userData['branchCode'].toString();
            print('Using branchCode from userData: $_branchCode');
          } 
          // Then try groupId as fallback
          else if (userData.containsKey('groupId') && userData['groupId'] != null && userData['groupId'].toString().isNotEmpty) {
            _branchCode = userData['groupId'].toString();
            print('Using groupId as branchCode: $_branchCode');
          }
          // Finally try BranchCode (different casing)
          else if (userData.containsKey('BranchCode') && userData['BranchCode'] != null && userData['BranchCode'].toString().isNotEmpty) {
            _branchCode = userData['BranchCode'].toString();
            print('Using BranchCode from userData: $_branchCode');
          }
          // Default to '1' if nothing found
          else {
            _branchCode = '1';
            print('No branch code found in userData, using default: $_branchCode');
          }
        } else {
          _branchCode = '1';
          print('No user data found, using default branch code: $_branchCode');
          
          // Create a default userData map
          _userData = {'userName': '', 'userId': ''};
          print('DEBUG - Created default userData');
        }
      });
    } catch (e) {
      setState(() {
        _branchCode = '1';
        print('Error loading user data: $e, using default branch code: $_branchCode');
        
        // Create a default userData map
        _userData = {'userName': '', 'userId': ''};
        print('DEBUG - Created default userData after error');
      });
    }
  }

  Future<void> _fetchReturnData() async {
    // DEBUG: Print current token to verify it's correctly stored
    try {
      final token = await _authService.getToken();
      debugPrint('🔴 DEBUG: Current token before fetch: ${token != null ? "Found (${token.length} chars)" : "NULL"}');
      
      // If token is null, try to log the user out and redirect to login page
      if (token == null || token.isEmpty) {
        debugPrint('🔴 DEBUG: Token is null or empty, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog
        await CustomModals.showFailedModal(
          context: context,
          message: 'Sesi anda telah berakhir. Silakan login kembali.',
          onPressed: () {
            Navigator.of(context).pop();
            _authService.logout().then((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
          },
        );
        return;
      }
      
      // Validate token before proceeding
      debugPrint('🔴 DEBUG: Validating token before fetch...');
      final isTokenValid = await _apiService.checkTokenValidity();
      if (!isTokenValid) {
        debugPrint('🔴 DEBUG: Token validation failed, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog
        await CustomModals.showFailedModal(
          context: context,
          message: 'Sesi anda telah berakhir. Silakan login kembali.',
          onPressed: () {
            Navigator.of(context).pop();
            _authService.logout().then((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
          },
        );
        return;
      }
      
      debugPrint('🔴 DEBUG: Token validation successful, proceeding with fetch');
    } catch (e) {
      debugPrint('🔴 DEBUG: Error getting token: $e');
    }
    
    final idCrf = _idCRFController.text.trim();
    if (idCrf.isEmpty) {
      await _showErrorDialog('ID CRF tidak boleh kosong');
      return;
    }
    
    setState(() { 
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      // Debug: Print state before fetch
      print('Fetching return data for ID CRF: $idCrf');
      
      final response = await _apiService.getReturnHeaderAndCatridge(idCrf, branchCode: _branchCode);
      
      if (response.success) {
        setState(() {
          _returnHeaderResponse = response;
          _errorMessage = '';
          
          // Set jamMulai with current time
          final now = DateTime.now();
          _jamMulaiController.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          
          // Create the cartridge section keys based on the response
          _cartridgeSectionKeys.clear();
          if (response.data.isNotEmpty) {
            for (int i = 0; i < response.data.length; i++) {
              _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
            }
            
            // For debugging
            print('Created ${_cartridgeSectionKeys.length} cartridge section keys for ${response.data.length} catridges');
            for (int i = 0; i < response.data.length; i++) {
              print('Catridge ${i+1}: Code=${response.data[i].catridgeCode}, Type=${response.data[i].typeCatridge}, TypeTrx=${response.data[i].typeCatridgeTrx ?? "C"}');
            }
          }
        });
      } else {
        setState(() {
          _errorMessage = response.message;
        });
        await _showErrorDialog(response.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      await _showErrorDialog(e.toString());
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await CustomModals.showFailedModal(
      context: context,
      message: message,
      onPressed: () {
        Navigator.of(context).pop();
        // If error is about serah terima, maybe provide a button to go to CPC
        if (message.contains('serah terima')) {
          // TODO: Navigate to CPC menu or show instructions
        }
      },
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    await CustomModals.showSuccessModal(
      context: context,
      message: message,
    );
  }

  void _openBarcodeScanner() async {
    // TODO: Implementasi scan barcode dan set _idCRFController.text
  }

  // Check if all forms are valid
  bool get _isFormsValid {
    if (_cartridgeSectionKeys.isEmpty) return false;
    
    // Check all cartridge sections
    for (var key in _cartridgeSectionKeys) {
      if (!(key.currentState?.isFormValid ?? false)) {
        return false;
      }
    }
    
    return true;
  }
  
  // Helper method to format currency
  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp. $formatted';
  }

  // NEW: Calculate totals from all cartridge sections and update detail return forms
  void _calculateAndUpdateDetailReturn() {
    // Initialize totals for each denomination
    Map<String, int> totalLembar = {
      '100K': 0, '75K': 0, '50K': 0, '20K': 0,
      '10K': 0, '5K': 0, '2K': 0, '1K': 0,
    };
    
    Map<String, int> totalNominal = {
      '100K': 0, '75K': 0, '50K': 0, '20K': 0,
      '10K': 0, '5K': 0, '2K': 0, '1K': 0,
    };
    
    // Sum up values from all cartridge sections
    for (var key in _cartridgeSectionKeys) {
      final sectionState = key.currentState;
      if (sectionState != null) {
        sectionState.denomControllers.forEach((denom, controller) {
          if (controller.text.isNotEmpty) {
            try {
              final count = int.parse(controller.text);
              totalLembar[denom] = (totalLembar[denom] ?? 0) + count;
              
              // Calculate nominal value
              int denomValue = 0;
              switch (denom) {
                case '100K': denomValue = 100000; break;
                case '75K': denomValue = 75000; break;
                case '50K': denomValue = 50000; break;
                case '20K': denomValue = 20000; break;
                case '10K': denomValue = 10000; break;
                case '5K': denomValue = 5000; break;
                case '2K': denomValue = 2000; break;
                case '1K': denomValue = 1000; break;
              }
              totalNominal[denom] = (totalNominal[denom] ?? 0) + (count * denomValue);
            } catch (e) {
              // Ignore parsing errors
            }
          }
        });
      }
    }
    
    // Update detail return controllers
    totalLembar.forEach((denom, total) {
      _detailReturnLembarControllers[denom]?.text = total.toString();
    });
    
    totalNominal.forEach((denom, total) {
      _detailReturnNominalControllers[denom]?.text = _formatCurrency(total);
    });
  }

  // Show TL approval dialog
  Future<void> _showTLApprovalDialog() async {
    // Periksa apakah semua cartridge sections telah divalidasi
    bool allSectionsValidated = true;
    bool anyManualMode = false;
    
    for (var key in _cartridgeSectionKeys) {
      if (key.currentState != null) {
        // Jika section tidak semua field di-scan, tandai belum valid
        if (!key.currentState!.allFieldsScanned) {
          allSectionsValidated = false;
          break;
        }
      }
    }
    
    // Jika semua section divalidasi dengan scan atau dalam mode manual, bisa langsung submit
    if (allSectionsValidated) {
      // Jika ada yang menggunakan mode manual, tetap minta approval TL
      if (anyManualMode) {
        _tlNikController.clear();
        _tlPasswordController.clear();
        
        return showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(
                'Approval TL Supervisor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NIK TL SPV',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
                      ),
                      child: TextField(
                        controller: _tlNikController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          suffixIcon: Icon(Icons.person_outline, color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
                      ),
                      child: TextField(
                        controller: _tlPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          suffixIcon: Icon(Icons.visibility, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Batal'),
                ),
                _isSubmitting
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Approve'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _validateTLAndSubmit();
                        },
                      ),
              ],
            );
          },
        );
      } else {
        // Jika semua divalidasi dengan scan dan tidak ada mode manual, langsung submit
        _submitReturnData();
      }
    } else {
      // Jika belum semua divalidasi, tampilkan pesan error
      await _showErrorDialog('Harap lengkapi validasi scan untuk semua field atau gunakan mode manual');
    }
  }

  // Navigate to summary page with cartridge data
  Future<void> _navigateToSummaryPage() async {
    // Collect cartridge data from all sections
    List<Map<String, dynamic>> cartridgeData = [];
    
    for (int i = 0; i < _cartridgeSectionKeys.length; i++) {
      final key = _cartridgeSectionKeys[i];
      if (key.currentState != null) {
        final state = key.currentState!;
        
        // Get typeCatridgeTrx from return header data
        String typeCatridgeTrx = 'C'; // Default
        if (_returnHeaderResponse?.data != null && i < _returnHeaderResponse!.data.length) {
          typeCatridgeTrx = _returnHeaderResponse!.data[i].typeCatridgeTrx ?? 'C';
        }
        
        // Collect data from each cartridge section
        Map<String, dynamic> data = {
          'noCatridge': state.noCatridgeController.text,
          'sealCatridge': state.noSealController.text,
          'catridgeFisik': state.catridgeFisikController.text,
          'bagCode': state.selectedBagCode,
          'sealCode': state.selectedSealCode,
          'kondisiSeal': state.kondisiSeal,
          'kondisiCatridge': state.kondisiCatridge,
          'typeCatridgeTrx': typeCatridgeTrx,
        };
        
        // Add denomination data
        for (String denom in ['1K', '2K', '5K', '10K', '20K', '50K', '100K']) {
          data['lembar_$denom'] = state.denomControllers[denom]?.text ?? '0';
          data['nominal_$denom'] = state.denomControllers[denom]?.text ?? '0';
        }
        
        cartridgeData.add(data);
      }
    }
    
    // Navigate to summary page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReturnSummaryPage(
          returnData: _returnHeaderResponse,
          cartridgeData: cartridgeData,
          detailReturnLembarControllers: _detailReturnLembarControllers,
          detailReturnNominalControllers: _detailReturnNominalControllers,
        ),
      ),
    );
  }

  // Validate TL credentials and submit data
  Future<void> _validateTLAndSubmit() async {
    if (_tlNikController.text.isEmpty || _tlPasswordController.text.isEmpty) {
      await _showErrorDialog('NIK dan Password TL harus diisi');
      return;
    }
    
    if (mounted) setState(() { _isSubmitting = true; });
    
    try {
      // Validate TL credentials
      final tlResponse = await _apiService.validateTLSupervisor(
        nik: _tlNikController.text,
        password: _tlPasswordController.text,
      );
      
      if (!tlResponse.success) {
        await _showErrorDialog(tlResponse.message);
        if (mounted) setState(() { _isSubmitting = false; });
        return;
      }
      
      // 1. Update Planning RTN first - this is crucial for correct flow
      print('Updating Planning RTN...');
      final updateParams = {
        "idTool": _idToolController.text,
        "CashierReturnCode": _userData?['nik'] ?? '',
        "TableReturnCode": _userData?['tableCode'] ?? '',
        "DateStartReturn": DateTime.now().toIso8601String(),
        "WarehouseCode": _userData?['warehouseCode'] ?? 'Cideng',
        "UserATMReturn": _tlNikController.text,
        "SPVBARusak": _tlNikController.text,
        "IsManual": "N"
      };
      
      final updateResponse = await _apiService.updatePlanningRTN(updateParams);
      
      if (!updateResponse.success) {
        await _showErrorDialog('Gagal update planning RTN: ${updateResponse.message}');
        if (mounted) setState(() { _isSubmitting = false; });
        return;
      }
      
      print('Planning RTN updated successfully!');
      
      // 2. Now insert each catridge data into RTN
      if (_returnHeaderResponse?.data == null || _returnHeaderResponse!.data.isEmpty) {
        await _showErrorDialog('Tidak ada data catridge untuk diproses');
        if (mounted) setState(() { _isSubmitting = false; });
        return;
      }
      
      // Get NIK from userData with proper error checking
      String userNIK = '';
      if (_userData != null) {
        // Try all possible keys for NIK (case insensitive)
        if (_userData!.containsKey('nik')) {
          userNIK = _userData!['nik'].toString();
        } else if (_userData!.containsKey('NIK')) {
          userNIK = _userData!['NIK'].toString();
        } else if (_userData!.containsKey('userId')) {
          userNIK = _userData!['userId'].toString();
        } else if (_userData!.containsKey('userID')) {
          userNIK = _userData!['userID'].toString();
        } else if (_userData!.containsKey('id')) {
          userNIK = _userData!['id'].toString();
        } else if (_userData!.containsKey('ID')) {
          userNIK = _userData!['ID'].toString();
        }
        
        // Log the NIK value for debugging
        print('DEBUG - Using UserInput NIK: $userNIK');
        print('DEBUG - Available userData keys: ${_userData!.keys.toList()}');
        print('DEBUG - Complete userData: $_userData');
      } else {
        print('ERROR - userData is null, cannot get NIK');
      }
      
      // If NIK is still empty, use a hardcoded value to prevent API error
      if (userNIK.isEmpty) {
        print('WARNING - Using default NIK since userData does not contain NIK');
                  userNIK = ''; // No default NIK
      }
      
      bool allSuccess = true;
      String errorMessage = '';
      
      // Process each catridge
      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
        final catridge = _returnHeaderResponse!.data[i];
        
        print('Processing catridge ${i+1} of ${_returnHeaderResponse!.data.length}: ${catridge.catridgeCode}');
        print('DEBUG - Sending to API: idTool=${_idToolController.text}, userInput=$userNIK');
        
        // Send to RTN endpoint dengan parameter sesuai ketentuan
        final rtneResponse = await _apiService.insertReturnAtmCatridge(
          // field Id Tool diisi ke IdTool
          idTool: _idToolController.text,
          // field No Bag diisi ke BagCode
          bagCode: catridge.bagCode ?? '0',
          // field No Catridge diisi ke CatridgeCode
          catridgeCode: catridge.catridgeCode,
          // field Seal Code diisi ke SealCode
          sealCode: '0', // Use default or get from catridge data if available
          // field No Seal diisi ke CatridgeSeal
          catridgeSeal: catridge.catridgeSeal,
          // DenomCode diisi TEST
          denomCode: 'TEST',
          // qty default diisi 0
          qty: '0',
          // nik saat login yang tersimpan akan mengisi ke UserInput
          userInput: userNIK,
          // N untuk isBalikKaset
          isBalikKaset: "N",
          // CatridgeCodeOld diisi TEST
          catridgeCodeOld: "TEST",
          // Parameter scan status - using default values for this endpoint
          scanCatStatus: "SCAN", 
          scanCatStatusRemark: "Auto-processed from return header",
          scanSealStatus: "SCAN",
          scanSealStatusRemark: "Auto-processed from return header"
        );
        
        if (!rtneResponse.success) {
          allSuccess = false;
          errorMessage = rtneResponse.message;
          print('Failed to insert catridge ${catridge.catridgeCode}: ${rtneResponse.message}');
          break;
        }
        
        print('Successfully inserted catridge ${catridge.catridgeCode}');
      }
      
      if (mounted) setState(() { _isSubmitting = false; });
      
      if (allSuccess) {
        // Show success dialog
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Data return berhasil disimpan',
          onPressed: () {
            Navigator.of(context).pop();
            // Return to home page
            Navigator.of(context).pop(true);
          },
        );
      } else {
        await _showErrorDialog('Gagal menyimpan data return: $errorMessage');
      }
    } catch (e) {
      if (mounted) setState(() { _isSubmitting = false; });
      await _showErrorDialog('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> _submitReturnData() async {
    if (_returnHeaderResponse == null || _returnHeaderResponse!.data.isEmpty) {
      if (mounted) setState(() { _errorMessage = 'Tidak ada data untuk disubmit'; });
      return;
    }

    if (mounted) setState(() { _isLoading = true; _errorMessage = ''; });
    
    try {
      // Check if we have any cartridge sections
      if (_cartridgeSectionKeys.isEmpty) {
        throw Exception('Tidak ada data catridge untuk disubmit');
      }
      
      // Get NIK from userData with proper error checking
      String userNIK = '';
      if (_userData != null) {
        // Try all possible keys for NIK (case insensitive)
        if (_userData!.containsKey('nik')) {
          userNIK = _userData!['nik'].toString();
        } else if (_userData!.containsKey('NIK')) {
          userNIK = _userData!['NIK'].toString();
        } else if (_userData!.containsKey('userId')) {
          userNIK = _userData!['userId'].toString();
        } else if (_userData!.containsKey('userID')) {
          userNIK = _userData!['userID'].toString();
        } else if (_userData!.containsKey('id')) {
          userNIK = _userData!['id'].toString();
        } else if (_userData!.containsKey('ID')) {
          userNIK = _userData!['ID'].toString();
        }
        
        // Log the NIK value for debugging
        print('DEBUG - Using UserInput NIK: $userNIK');
        print('DEBUG - Available userData keys: ${_userData!.keys.toList()}');
        print('DEBUG - Complete userData: $_userData');
      } else {
        print('ERROR - userData is null, cannot get NIK');
      }
      
      // If NIK is still empty, use a hardcoded value to prevent API error
      if (userNIK.isEmpty) {
        print('WARNING - Using default NIK since userData does not contain NIK');
                  userNIK = ''; // No default NIK
      }
      
      bool allSuccess = true;
      
      // Submit data for each cartridge section
      for (int i = 0; i < _cartridgeSectionKeys.length; i++) {
        if (i >= _returnHeaderResponse!.data.length) break;
        
        final catridgeState = _cartridgeSectionKeys[i].currentState!;
        
        // Log the parameters being sent to the API
        print('DEBUG - Sending to API: idTool=${_idToolController.text}, userInput=$userNIK');
        
        // Implementasi parameter sesuai ketentuan
        final response = await _apiService.insertReturnAtmCatridge(
          // field Id Tool diisi ke IdTool
          idTool: _idToolController.text,
          // field No Bag diisi ke BagCode
          bagCode: catridgeState.bagCode ?? '',
          // field No Catridge diisi ke CatridgeCode
          catridgeCode: catridgeState.noCatridgeController.text,
          // field Seal Code diisi ke SealCode
          sealCode: catridgeState.sealCode ?? '',
          // field No Seal diisi ke CatridgeSeal
          catridgeSeal: catridgeState.noSealController.text,
          // DenomCode diisi TEST
          denomCode: 'TEST',
          // qty default diisi 0
          qty: '0',
          // nik saat login yang tersimpan akan mengisi ke UserInput - make sure this is filled
          userInput: userNIK,
          // N untuk isBalikKaset
          isBalikKaset: 'N',
          // CatridgeCodeOld diisi TEST
          catridgeCodeOld: 'TEST',
          // Parameter scan status - updated to use manual mode data
          scanCatStatus: catridgeState._noCatridgeManualMode ? "MANUAL" : "SCAN",
          scanCatStatusRemark: catridgeState._noCatridgeManualMode ? 
            "${catridgeState._noCatridgeAlasanController.text} - ${catridgeState._noCatridgeRemarkController.text}" : 
            "Scanned from mobile app",
          scanSealStatus: catridgeState._noSealManualMode ? "MANUAL" : "SCAN",
          scanSealStatusRemark: catridgeState._noSealManualMode ? 
            "${catridgeState._noSealAlasanController.text} - ${catridgeState._noSealRemarkController.text}" : 
            "Scanned from mobile app",
          // Additional manual mode parameters - removed as these are not valid API parameters
        );
        
        if (!response.success) {
          allSuccess = false;
          throw Exception(response.message);
        }
      }
      
      // Tampilkan dialog sukses
      await _showSuccessDialog('Data return berhasil disubmit');
      
      // Reset form
      _idCRFController.clear();
      _idToolController.clear();
      setState(() {
        _returnHeaderResponse = null;
      });
      
    } catch (e) {
      if (mounted) setState(() { _errorMessage = e.toString(); });
      await _showErrorDialog('Error submit data: ${e.toString()}');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // Modified to fetch data by ID Tool
  Future<void> _fetchDataByIdTool(String idTool) async {
    if (idTool.isEmpty) {
      return;
    }
    
    setState(() { 
      _isLoading = true;
    });
    
    try {
      // Use a more direct approach to fetch data
      final result = await _apiService.validateAndGetReplenish(
              idTool: idTool,
        branchCode: _branchCode
      );

      if (result.success && result.data != null) {
        setState(() {
          // Create a header response with all the new fields - ensure all values are converted to String
          _returnHeaderResponse = ReturnHeaderResponse(
            success: true,
            message: "Data ditemukan",
            header: ReturnHeaderData(
              atmCode: result.data!.atmCode.toString(),
              namaBank: result.data!.codeBank.toString(),
              lokasi: result.data!.lokasi.toString(),
              typeATM: result.data!.idTypeAtm.toString(),
              // Add new fields - ensure all are converted to String
              codeBank: result.data!.codeBank.toString(),
              jnsMesin: result.data!.jnsMesin.toString(),
              idTypeAtm: result.data!.idTypeAtm.toString(),
              timeSTReturn: result.data!.timeSTReturn.toString(),
            ),
            data: result.data!.catridges.map((c) => ReturnCatridgeData(
              idTool: result.data!.idToolPrepare.toString(),
              catridgeCode: c.catridgeCode.toString(),
              catridgeSeal: c.catridgeSeal.toString(),
              denomCode: '',
              typeCatridge: c.typeCatridgeTrx.toString(),
              bagCode: c.bagCode.toString(),
              sealCodeReturn: c.sealCodeReturn.toString(),
            )).toList(),
          );
          
          // Set current time to jam mulai when data is fetched successfully
          _setCurrentTime();
        });
      } else {
        // Show error using CustomModals instead of setting _errorMessage
        await CustomModals.showFailedModal(
          context: context,
          message: result.message,
        );
      }
    } catch (e) {
      // Show error using CustomModals instead of setting _errorMessage
      await CustomModals.showFailedModal(
        context: context,
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isLoading = false;
                });
              }
            }

  // Add method to set current time and date
  void _setCurrentTime() {
    final now = DateTime.now();
    final formattedTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _jamMulaiController.text = formattedTime;
    
    // Set tanggal replenish to current date
    _setCurrentDate();
  }
  
  // Add method to set current date for tanggal replenish
  void _setCurrentDate() {
    final now = DateTime.now();
    final formattedDate = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _tanggalReplenishController.text = formattedDate;
  }

  // Method for building form fields with proper styling
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
    String? hintText,
    bool hasIcon = false,
    bool enableScan = false,
    IconData iconData = Icons.search,
    VoidCallback? onIconPressed,
    required bool isSmallScreen,
    Function(String)? onChanged,
    Function(bool)? onFocusChange,
  }) {
    return SizedBox(
      height: 45, // Fixed height for consistency with prepare mode
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: 120, // Wider label (was 80/100)
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14, // Fixed size
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Input field section with underline - expandable
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Focus(
                      onFocusChange: onFocusChange,
                      child: TextField(
                        controller: controller,
                        readOnly: readOnly,
                        style: const TextStyle(fontSize: 14), // Fixed size
                        decoration: InputDecoration(
                          hintText: hintText,
                          contentPadding: const EdgeInsets.only(
                            left: 6,
                            right: 6,
                            bottom: 8,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: onChanged,
                      ),
                    ),
                  ),
                  
                  // Icons positioned on the underline
                  if (enableScan)
                    Container(
                      width: 24, // Fixed width
                      height: 24, // Fixed height
                      margin: const EdgeInsets.only(
                        left: 6,
                        bottom: 4,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.blue,
                          size: 18, // Fixed size
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(), // Remove constraints
                        onPressed: onIconPressed,
                      ),
                    ),
                  
                  if (hasIcon)
                    Container(
                      width: 24, // Fixed width
                      height: 24, // Fixed height
                      margin: const EdgeInsets.only(
                        left: 6,
                        bottom: 4,
                      ),
                      child: Icon(
                        iconData,
                        color: Colors.grey,
                        size: 18, // Fixed size
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

  // Method to scan ID Tool
  Future<void> _scanIdTool() async {
    try {
      // Navigate to barcode scanner with stream approach
      final result = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan ID Tool',
            fieldKey: 'idTool',
            fieldLabel: 'ID Tool',
            sectionId: null, // ID Tool doesn't belong to a specific section
            onBarcodeDetected: (String barcode) {
              // This will be handled by stream, but we still need the callback
              print('🎯 ID Tool callback: $barcode');
            },
          ),
        ),
      );
      
      // If no barcode was scanned (user cancelled), return early
      if (result == null) {
        print('ID Tool scanning cancelled');
        return;
      }
      
      String barcode = result;
      print('🎯 ID Tool scanned via navigation: $barcode');
      
      setState(() {
        _idToolController.text = barcode;
      });
      
      // Reset all scan validation states in all cartridge sections
      for (var key in _cartridgeSectionKeys) {
        if (key.currentState != null) {
          key.currentState!._resetAllScanStates();
        }
      }
      
      // Fetch data using the scanned ID Tool
      _fetchDataByIdTool(barcode);
    } catch (e) {
      print('Error opening barcode scanner: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal membuka scanner: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTabletOrLandscapeMobile = size.width >= 600;
    final isLandscape = size.width > size.height;
    
    return Scaffold(
      appBar: null, // Remove default AppBar
      body: Column(
        children: [
          // Custom header - matched with konsol_mode
          Container(
            height: isTabletOrLandscapeMobile ? 80 : 70,
            padding: EdgeInsets.symmetric(
              horizontal: isTabletOrLandscapeMobile ? 32.0 : 24.0,
              vertical: isTabletOrLandscapeMobile ? 16.0 : 12.0,
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
                    width: isTabletOrLandscapeMobile ? 48 : 40,
                    height: isTabletOrLandscapeMobile ? 48 : 40,
                    child: Image.asset(
                      'assets/images/back.png',
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: isTabletOrLandscapeMobile ? 20 : 16),
                
                // Title
                Text(
                  'Return Mode',
                  style: TextStyle(
                    fontSize: isTabletOrLandscapeMobile ? 28 : 24,
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
              _userData?['role'] ?? 'CRF_KONSOL', // Get role from user data, fallback to default
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
                _returnHeaderResponse = null;
                _idToolController.clear();
                _jamMulaiController.clear();
                _errorMessage = '';
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
                        nik = _userData != null && _userData!.containsKey('userId') ? _userData!['userId'] : '';
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
          ),
          
          // Rest of the content
          Expanded(
            child: Container(
              color: Colors.white,
              child: RefreshIndicator(
                onRefresh: () async {
                  // Reset content
                  setState(() {
                    _returnHeaderResponse = null;
                    _idToolController.clear();
                    _jamMulaiController.clear();
                    _errorMessage = '';
                  });
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use Row for wide screens, Column for narrow screens
                    final useRow = constraints.maxWidth >= 600;
                    
                    // Create dynamic cartridge sections based on API response
                    List<Widget> cartridgeSections = [];
                    
                    // Loading indicator
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    // Note: Error messages are now shown using CustomModals instead of inline display
                    // This ensures forms below remain visible even when there are validation errors
                    
                    // Clear and recreate keys when response changes
                    if (_returnHeaderResponse?.data != null && _cartridgeSectionKeys.length != _returnHeaderResponse!.data.length) {
                      _cartridgeSectionKeys.clear();
                      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                        _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                        print('Created key for item ${i+1} of ${_returnHeaderResponse!.data.length}');
                      }
                    }
                    
                    // Build cartridge sections based on response data
                    if (_returnHeaderResponse?.data != null) {
                      print('Building ${_returnHeaderResponse!.data.length} cartridge sections');
                      print('Current keys: ${_cartridgeSectionKeys.length}');
                      
                      // Ensure we have the right number of keys
                      if (_cartridgeSectionKeys.length != _returnHeaderResponse!.data.length) {
                        _cartridgeSectionKeys.clear();
                        for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                          _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                          print('Created key for item ${i+1} of ${_returnHeaderResponse!.data.length}');
                        }
                      }
                      
                      for (int i = 0; i < _returnHeaderResponse!.data.length; i++) {
                        if (i < _cartridgeSectionKeys.length) { // Safety check
                          final data = _returnHeaderResponse!.data[i];
                          
                          // Debug the data
                          print('Data at index $i: id=${data.idTool}, code=${data.catridgeCode}, typeTrx=${data.typeCatridgeTrx}');
                          
                          // Determine section title based on typeCatridgeTrx
                          String sectionTitle;
                          final typeCatridgeTrx = data.typeCatridgeTrx?.toUpperCase() ?? 'C';
                          
                          switch (typeCatridgeTrx) {
                            case 'C':
                              sectionTitle = 'Catridge ${i + 1}';
                              break;
                            case 'D':
                              sectionTitle = 'Divert ${i + 1}';
                              break;
                            case 'P':
                              sectionTitle = 'Pocket';
                              break;
                            default:
                              sectionTitle = 'Catridge ${i + 1}';
                          }
                          
                          print('Adding section: $sectionTitle for index $i');
                          
                          cartridgeSections.add(
                            Column(
                              children: [
                                CartridgeSection(
                                  key: _cartridgeSectionKeys[i],
                                  title: sectionTitle,
                                  returnData: data,
                                  parentIdToolController: _idToolController,
                                  sectionId: 'section_$i', // NEW: Add unique section ID
                                  onDenomChanged: _calculateAndUpdateDetailReturn, // NEW: Add callback
                                ),
                                const SizedBox(height: 16), // Consistent spacing
                              ],
                            ),
                          );
                        }
                      }
                    } else {
                      // Add at least one empty cartridge section if no data
                      _cartridgeSectionKeys.clear();
                      _cartridgeSectionKeys.add(GlobalKey<_CartridgeSectionState>());
                      
                      cartridgeSections.add(
                        Column(
                          children: [
                            CartridgeSection(
                              key: _cartridgeSectionKeys[0],
                              title: 'Catridge 1',
                              returnData: null,
                              parentIdToolController: _idToolController,
                              sectionId: 'section_0', // NEW: Add unique section ID
                              onDenomChanged: _calculateAndUpdateDetailReturn, // NEW: Add callback
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    }
                    
                    // Build the main content
                    Widget mainContent;
                    
                    // ID CRF, Jam Mulai, and Tanggal Replenish fields
                    Widget idCrfAndTimeFields = Container(
                      margin: const EdgeInsets.only(bottom: 20), // Increased margin
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID CRF field
                          Expanded(
                            flex: 1,
                            child: _buildFormField(
                              label: 'ID CRF :',
                              controller: _idToolController,
                              enableScan: true,
                              isSmallScreen: false,
                              hintText: 'Masukkan ID CRF',
                              onIconPressed: () => _scanIdTool(),
                              onFocusChange: (hasFocus) {
                                // Trigger API call when user leaves the field (loses focus)
                                if (!hasFocus && _idToolController.text.isNotEmpty) {
                                  _fetchDataByIdTool(_idToolController.text);
                                }
                              },
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Jam Mulai field
                          Expanded(
                            flex: 1,
                            child: _buildFormField(
                              label: 'Jam Mulai :',
                              controller: _jamMulaiController,
                              readOnly: true,
                              hasIcon: true,
                              iconData: Icons.access_time,
                              isSmallScreen: false,
                              hintText: '--:--',
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Tanggal Replenish field
                          Expanded(
                            flex: 1,
                            child: _buildFormField(
                              label: 'Tanggal Replenish:',
                              controller: _tanggalReplenishController,
                              readOnly: true,
                              hasIcon: true,
                              iconData: Icons.calendar_today,
                              isSmallScreen: false,
                              hintText: 'dd/mm/yyyy',
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    // Wrap in SingleChildScrollView for proper scrolling
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: useRow
                          ? Column(
                              children: [
                                idCrfAndTimeFields,
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        children: cartridgeSections,
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    Expanded(
                                      flex: 4,
                                      child: DetailSection(
                                        returnData: _returnHeaderResponse,
                                        onSubmitPressed: _navigateToSummaryPage,
                                        isLandscape: false, // Consistent styling
                                        detailReturnLembarControllers: _detailReturnLembarControllers,
                                        detailReturnNominalControllers: _detailReturnNominalControllers,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                idCrfAndTimeFields,
                                ...cartridgeSections,
                                DetailSection(
                                  returnData: _returnHeaderResponse,
                                  onSubmitPressed: _navigateToSummaryPage,
                                  isLandscape: false, // Consistent styling
                                  detailReturnLembarControllers: _detailReturnLembarControllers,
                                  detailReturnNominalControllers: _detailReturnNominalControllers,
                                ),
                              ],
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CartridgeSection extends StatefulWidget {
  final String title;
  final ReturnCatridgeData? returnData;
  final TextEditingController parentIdToolController;
  final String sectionId; // NEW: Add section ID
  final VoidCallback? onDenomChanged; // NEW: Add callback for denomination changes
  
  const CartridgeSection({
    Key? key, 
    required this.title, 
    this.returnData,
    required this.parentIdToolController,
    required this.sectionId, // NEW: Require section ID
    this.onDenomChanged, // NEW: Optional callback
  }) : super(key: key);

  @override
  State<CartridgeSection> createState() => _CartridgeSectionState();
}

class _CartridgeSectionState extends State<CartridgeSection> with AutoLogoutMixin {
  String? kondisiSeal;
  String? kondisiCatridge;
  String wsidValue = '';

  // Modified to only have two options
  final List<String> kondisiSealOptions = ['BAIK', 'PUTUS', 'HILANG', 'TIDAK UTUH', 'SEAL BEDA'];
  final List<String> kondisiCatridgeOptions = ['BAIK', 'CATRIDGE KEMBALI', 'CATRIDGE RUSAK', 'TAMBUR RUSAK'];
  
  // NEW: Getter for section ID
  String get sectionId => widget.sectionId;

  // NEW: Field-specific manual mode variables (following prepare_mode pattern)
  bool _noCatridgeManualMode = false; // For No. Catridge field
  bool _noSealManualMode = false; // For No. Seal field
  bool _bagCodeManualMode = false; // For Bag Code field
  bool _sealCodeManualMode = false; // For Seal Code field
  bool _catridgeFisikManualMode = false; // For Catridge Fisik field

  final TextEditingController noCatridgeController = TextEditingController();
  final TextEditingController noSealController = TextEditingController();
  final TextEditingController catridgeFisikController = TextEditingController();
  final TextEditingController bagCodeController = TextEditingController();
  final TextEditingController sealCodeReturnController = TextEditingController();
  final TextEditingController branchCodeController = TextEditingController();
  
  // NEW: Controllers for manual mode alasan and remark per field
  final TextEditingController _noCatridgeAlasanController = TextEditingController();
  final TextEditingController _noCatridgeRemarkController = TextEditingController();
  final TextEditingController _noSealAlasanController = TextEditingController();
  final TextEditingController _noSealRemarkController = TextEditingController();
  final TextEditingController _bagCodeAlasanController = TextEditingController();
  final TextEditingController _bagCodeRemarkController = TextEditingController();
  final TextEditingController _sealCodeAlasanController = TextEditingController();
  final TextEditingController _sealCodeRemarkController = TextEditingController();
  final TextEditingController _catridgeFisikAlasanController = TextEditingController();
  final TextEditingController _catridgeFisikRemarkController = TextEditingController();
  
  // NEW: Remark filled tracking per field
  bool _noCatridgeRemarkFilled = false;
  bool _noSealRemarkFilled = false;
  bool _bagCodeRemarkFilled = false;
  bool _sealCodeRemarkFilled = false;
  bool _catridgeFisikRemarkFilled = false;

  // NEW: Dropdown selection variables
  String? selectedBagCode;
  String? selectedSealCode;

  // Add getters for bagCode and sealCode (now from dropdown)
  String? get bagCode => selectedBagCode;
  String? get sealCode => selectedSealCode;
  
  // NEW: Getter untuk mengetahui apakah semua field telah di-scan (bagCode dan sealCode tidak perlu scan karena dropdown)
  bool get allFieldsScanned => 
    scannedFields['noCatridge'] == true &&
    scannedFields['noSeal'] == true;
  
  // NEW: Getter untuk mode validasi
  bool get isValidationComplete => allFieldsScanned;

  // NEW APPROACH: Use a map to track which fields have been scanned (removed bagCode and sealCode)
  Map<String, bool> scannedFields = {
    'noCatridge': false,
    'noSeal': false,
    'catridgeFisik': false,
  };

  // Helper methods to get dropdown data from parent
  List<String> _getAllBagCodesFromParent() {
    final parentState = context.findAncestorStateOfType<_ReturnModePageState>();
    return parentState?._getAllBagCodes() ?? [];
  }

  List<String> _getAllSealCodesFromParent() {
    final parentState = context.findAncestorStateOfType<_ReturnModePageState>();
    return parentState?._getAllSealCodes() ?? [];
  }

  // Build dropdown field widget for CartridgeSection
  Widget _buildDropdownFieldForBagCode(
    String label,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged,
    {bool isValid = true, String errorText = ''}
  ) {
    // Get screen size for responsive design
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isSmallScreen ? 40 : 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Label section - fixed width
              SizedBox(
                width: isSmallScreen ? 90 : 110,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                  child: Text(
                    '$label :',
                    style: TextStyle(
                      fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                      color: isValid ? Colors.black : Colors.red,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ),
              
              // Dropdown field with underline and dropdown icon
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isValid ? Colors.grey.shade400 : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedValue,
                            hint: Text(
                              'Pilih $label',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: isValid ? Colors.black : Colors.red,
                            ),
                            items: items.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: onChanged,
                            icon: Container(
                              width: isSmallScreen ? 30 : 40,
                              height: isSmallScreen ? 30 : 40,
                              margin: EdgeInsets.only(
                                left: isSmallScreen ? 4 : 6,
                                bottom: isSmallScreen ? 3 : 4,
                              ),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blue,
                                size: isSmallScreen ? 20 : 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Error text
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // Build dropdown field widget for Seal Code
  Widget _buildDropdownFieldForSealCode(
    String label,
    List<String> items,
    String? selectedValue,
    Function(String?) onChanged,
    {bool isValid = true, String errorText = ''}
  ) {
    // Get screen size for responsive design
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isSmallScreen ? 40 : 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Label section - fixed width
              SizedBox(
                width: isSmallScreen ? 90 : 110,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                  child: Text(
                    '$label :',
                    style: TextStyle(
                      fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                      color: isValid ? Colors.black : Colors.red,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ),
              
              // Dropdown field with underline and dropdown icon
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isValid ? Colors.grey.shade400 : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedValue,
                            hint: Text(
                              'Pilih $label',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            isExpanded: true,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: isValid ? Colors.black : Colors.red,
                            ),
                            items: items.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: onChanged,
                            icon: Container(
                              width: isSmallScreen ? 30 : 40,
                              height: isSmallScreen ? 30 : 40,
                              margin: EdgeInsets.only(
                                left: isSmallScreen ? 4 : 6,
                                bottom: isSmallScreen ? 3 : 4,
                              ),
                              child: Icon(
                                Icons.arrow_drop_down,
                                color: Colors.blue,
                                size: isSmallScreen ? 20 : 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Error text
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // NEW: Method to handle barcode results from stream
  void _handleStreamBarcodeResult(String fieldKey, String barcode, String label) async {
    print('🎯 CARTRIDGE [${widget.sectionId}]: Handling stream result for $fieldKey: $barcode');
    print('🎯 CARTRIDGE [${widget.sectionId}]: Current scannedFields state: $scannedFields');
    
    // Get the appropriate controller
    TextEditingController? controller = _getControllerForFieldKey(fieldKey);
    if (controller == null) {
      print('❌ CARTRIDGE [${widget.sectionId}]: No controller found for field: $fieldKey');
      return;
    }
    
    print('🎯 CARTRIDGE [${widget.sectionId}]: Controller current value: "${controller.text}"');
    
    // Validate barcode if field already has content
    if (controller.text.isNotEmpty && controller.text != barcode) {
      await CustomModals.showFailedModal(
        context: context,
        message: '❌ [${widget.sectionId}] Kode tidak sesuai! Expected: ${controller.text}, Scanned: $barcode',
      );
      return;
    }
    
    // Update the field if it's empty
    if (controller.text.isEmpty) {
      controller.text = barcode;
      print('🎯 CARTRIDGE [${widget.sectionId}]: Field updated with barcode: $barcode');
    }
    
    // CRITICAL: Only one setState call with all updates
    if (mounted) {
      setState(() {
        print('🎯 CARTRIDGE [${widget.sectionId}]: SETTING scannedFields[$fieldKey] = true');
        scannedFields[fieldKey] = true;
        
        // Update validation flags
        _updateValidationForField(fieldKey, barcode);
        
        // Pastikan field terkait ditandai sebagai valid
        if (fieldKey == 'noCatridge') {
          isNoCatridgeValid = true;
          noCatridgeError = '';
        } else if (fieldKey == 'noSeal') {
          isNoSealValid = true;
          noSealError = '';
        } else if (fieldKey == 'catridgeFisik') {
          isCatridgeFisikValid = true;
          catridgeFisikError = '';
        } else if (fieldKey == 'bagCode') {
          isBagCodeValid = true;
          bagCodeError = '';
        } else if (fieldKey == 'sealCode') {
          isSealCodeReturnValid = true;
          sealCodeReturnError = '';
        }
        
        print('✅ CARTRIDGE [${widget.sectionId}]: $fieldKey validated with checkmark - scannedFields[$fieldKey] = ${scannedFields[fieldKey]}');
      });
      
      // Show success message AFTER setState
      await CustomModals.showSuccessModal(
        context: context,
        message: '✅ [$sectionId] $label berhasil divalidasi: $barcode',
      );
      
      // Force rebuild untuk memastikan checkmark muncul
      Future.microtask(() {
        if (mounted) setState(() {});
      });
    }
  }
  
  // Helper method to get controller for field key
  TextEditingController? _getControllerForFieldKey(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        return noCatridgeController;
      case 'noSeal':
        return noSealController;
      case 'catridgeFisik':
        return catridgeFisikController;
      // bagCode and sealCode removed - now using dropdown
      default:
        return null;
    }
  }
  
  // Helper method to update validation flags
  void _updateValidationForField(String fieldKey, String barcode) {
    switch (fieldKey) {
      case 'noCatridge':
        isNoCatridgeValid = true;
        noCatridgeError = '';
        break;
      case 'noSeal':
        isNoSealValid = true;
        noSealError = '';
        break;
      case 'catridgeFisik':
        isCatridgeFisikValid = true;
        catridgeFisikError = '';
        break;
      case 'bagCode':
        isBagCodeValid = true;
        bagCodeError = '';
        break;
      case 'sealCode':
        isSealCodeReturnValid = true;
        sealCodeReturnError = '';
        break;
    }
  }
  
  // Method to reset all scan states
  void _resetAllScanStates() {
    if (mounted) {
      setState(() {
        scannedFields.forEach((key, value) {
          scannedFields[key] = false;
        });
      });
    }
  }

  final Map<String, TextEditingController> denomControllers = {
    '100K': TextEditingController(),
    '75K': TextEditingController(),
    '50K': TextEditingController(),
    '20K': TextEditingController(),
    '10K': TextEditingController(),
    '5K': TextEditingController(),
    '2K': TextEditingController(),
    '1K': TextEditingController(),
  };
  
  // NEW: Controllers for total calculations
  final TextEditingController totalLembarController = TextEditingController();
  final TextEditingController totalNominalController = TextEditingController();

  // Validation state
  bool isNoCatridgeValid = true;
  bool isNoSealValid = true;
  bool isCatridgeFisikValid = true;
  bool isKondisiSealValid = true;
  bool isKondisiCatridgeValid = true;
  bool isBagCodeValid = true;
  bool isSealCodeReturnValid = true;
  bool isSealCodeValid = true;
  bool isDenomValid = true;

  // Error messages
  String noCatridgeError = '';
  String noSealError = '';
  String catridgeFisikError = '';
  String kondisiSealError = '';
  String kondisiCatridgeError = '';
  String bagCodeError = '';
  String sealCodeReturnError = '';
  String denomError = '';

  // API service
  final ApiService _apiService = ApiService();
  bool _isValidating = false;
  bool _isLoading = false;
  
  // Data baru
  String _branchCode = '1'; // Default branch code

  // Helper method to format currency
  String _formatCurrency(int amount) {
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
    return 'Rp. $formatted';
  }

  @override
  void initState() {
    super.initState();
    _loadReturnData();
    _loadUserData();
    
    // Set default branch code
    branchCodeController.text = _branchCode;
    
    // Initialize scannedFields map
    scannedFields = {
      'noCatridge': false,
      'noSeal': false,
      'catridgeFisik': false,
      'bagCode': false,
      'sealCode': false,
    };
    
    // NEW: Initialize total controllers with default values
    totalLembarController.text = '0';
    totalNominalController.text = _formatCurrency(0);
    
    // Debug log
    print('INIT: scannedFields initialized: $scannedFields');
  }

  @override
  void dispose() {
    noCatridgeController.dispose();
    noSealController.dispose();
    catridgeFisikController.dispose();
    bagCodeController.dispose();
    sealCodeReturnController.dispose();
    branchCodeController.dispose();
    for (var c in denomControllers.values) {
      c.dispose();
    }
    // NEW: Dispose total controllers
    totalLembarController.dispose();
    totalNominalController.dispose();
    super.dispose();
  }
  
  // NEW: Method to calculate totals for this section
  void _calculateSectionTotals() {
    int totalLembar = 0;
    int totalNominal = 0;
    
    denomControllers.forEach((denom, controller) {
      if (controller.text.isNotEmpty) {
        try {
          final count = int.parse(controller.text);
          totalLembar += count;
          
          // Calculate nominal value
          int denomValue = 0;
          switch (denom) {
            case '100K': denomValue = 100000; break;
            case '75K': denomValue = 75000; break;
            case '50K': denomValue = 50000; break;
            case '20K': denomValue = 20000; break;
            case '10K': denomValue = 10000; break;
            case '5K': denomValue = 5000; break;
            case '2K': denomValue = 2000; break;
            case '1K': denomValue = 1000; break;
          }
          totalNominal += count * denomValue;
        } catch (e) {
          // Ignore invalid numbers
        }
      }
    });
    
    // Update total controllers
     totalLembarController.text = totalLembar.toString();
     totalNominalController.text = _formatCurrency(totalNominal);
   }
   
   // NEW: Build total field with same design as form No. Catridge
   Widget _buildTotalField(String label, TextEditingController controller) {
     final size = MediaQuery.of(context).size;
     final isSmallScreen = size.width < 600;
     
     return Container(
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.end,
         children: [
           // Label section - fixed width
           SizedBox(
             width: isSmallScreen ? 90 : 110,
             child: Padding(
               padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
               child: Text(
                 '$label :',
                 style: TextStyle(
                   fontWeight: FontWeight.bold,
                   color: Colors.black,
                   fontSize: isSmallScreen ? 12 : 14,
                 ),
               ),
             ),
           ),
           
           // Input field with underline (same design as No. Catridge)
           Expanded(
             child: Container(
               decoration: BoxDecoration(
                 border: Border(
                   bottom: BorderSide(
                     color: Colors.grey.shade400,
                     width: 1.5,
                   ),
                 ),
               ),
               child: TextField(
                 controller: controller,
                 readOnly: true,
                 textAlign: TextAlign.center,
                 style: TextStyle(
                   fontSize: isSmallScreen ? 12 : 14,
                   color: Colors.black,
                   fontWeight: FontWeight.bold,
                 ),
                 decoration: InputDecoration(
                   contentPadding: EdgeInsets.only(
                     left: isSmallScreen ? 4 : 6,
                     right: isSmallScreen ? 4 : 6,
                     bottom: isSmallScreen ? 6 : 8,
                   ),
                   border: InputBorder.none,
                   isDense: true,
                 ),
               ),
             ),
           ),
         ],
       ),
     );
   }
  
  // Load user data untuk mendapatkan branch code
  Future<void> _loadUserData() async {
    try {
      final authService = AuthService();
      final userData = await authService.getUserData();
      if (userData != null) {
        setState(() {
          // First try to get branchCode directly
          if (userData.containsKey('branchCode') && userData['branchCode'] != null && userData['branchCode'].toString().isNotEmpty) {
            _branchCode = userData['branchCode'].toString();
            print('CartridgeSection: Using branchCode from userData: $_branchCode');
          } 
          // Then try groupId as fallback
          else if (userData.containsKey('groupId') && userData['groupId'] != null && userData['groupId'].toString().isNotEmpty) {
            _branchCode = userData['groupId'].toString();
            print('CartridgeSection: Using groupId as branchCode: $_branchCode');
          }
          // Finally try BranchCode (different casing)
          else if (userData.containsKey('BranchCode') && userData['BranchCode'] != null && userData['BranchCode'].toString().isNotEmpty) {
            _branchCode = userData['BranchCode'].toString();
            print('CartridgeSection: Using BranchCode from userData: $_branchCode');
          }
          // Default to '1' if nothing found
          else {
            _branchCode = '1';
            print('CartridgeSection: No branch code found in userData, using default: $_branchCode');
          }
          
          branchCodeController.text = _branchCode;
        });
      }
    } catch (e) {
      print('CartridgeSection: Error loading user data: $e, using default branch code: 1');
      setState(() {
        _branchCode = '1';
        branchCodeController.text = _branchCode;
      });
    }
  }
  
  // New method to fetch data from API with provided idTool
  Future<void> fetchDataFromApi(String idTool) async {
    if (idTool.isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Masukkan ID Tool terlebih dahulu',
      );
      return;
    }
    
    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) return;
    
    setState(() {
      _isLoading = true;
      
      // Reset all scanned fields flags
      scannedFields.forEach((key, value) {
        scannedFields[key] = false;
      });
    });
    
    try {
      // Ensure branchCode is numeric
      String numericBranchCode = branchCodeController.text;
      if (branchCodeController.text.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCodeController.text)) {
        numericBranchCode = '1'; // Default to '1' if not numeric
        print('WARNING: Branch code is not numeric: "${branchCodeController.text}", using default: $numericBranchCode');
        branchCodeController.text = numericBranchCode;
      }
      
      // Log the request for debugging
      print('Fetching data with idTool: $idTool, branchCode: $numericBranchCode (original: ${branchCodeController.text})');
      
      // Create test URL for manual verification
      final String testUrl = 'http://10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish?idtool=$idTool&branchCode=$numericBranchCode';
      print('Test URL: $testUrl');
      
      final result = await safeApiCall(() => _apiService.validateAndGetReplenishRaw(
        idTool,
        numericBranchCode,
        catridgeCode: noCatridgeController.text.isNotEmpty ? noCatridgeController.text : null,
      ));
      
      if (result != null && result['success'] == true && result['data'] != null) {
        setState(() {
          // Set WSID from atmCode
          if (result['data']['atmCode'] != null) {
            wsidValue = result['data']['atmCode'].toString();
          }
          
          // Process catridge data if available
          if (result['data']['catridges'] != null && result['data']['catridges'] is List && (result['data']['catridges'] as List).isNotEmpty) {
            final catridgeData = (result['data']['catridges'] as List).first;
            
            // Fill fields from API data
            if (catridgeData['catridgeCode'] != null || catridgeData['CatridgeCode'] != null) {
              noCatridgeController.text = catridgeData['catridgeCode'] ?? catridgeData['CatridgeCode'] ?? '';
            }
            
            if (catridgeData['catridgeSeal'] != null || catridgeData['CatridgeSeal'] != null) {
              noSealController.text = catridgeData['catridgeSeal'] ?? catridgeData['CatridgeSeal'] ?? '';
            }
            
            if (catridgeData['bagCode'] != null) {
              bagCodeController.text = catridgeData['bagCode'] ?? '';
            }
            
            if (catridgeData['sealCodeReturn'] != null) {
              sealCodeReturnController.text = catridgeData['sealCodeReturn'] ?? '';
            }
            
            // Set validation flags
            isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
            isNoSealValid = noSealController.text.isNotEmpty;
            isBagCodeValid = true;
            isSealCodeReturnValid = true;
            
            // IMPORTANT: Reset all scanned fields flags
            scannedFields.forEach((key, value) {
              scannedFields[key] = false;
            });
            
            print('Scan states reset after API fetch:');
            print('Scanned fields: $scannedFields');
          } else {
            print('No catridges data found in response or empty list');
          }
        });
      } else {
        // Enhanced error handling
        String errorMessage = result?['message'] ?? 'Gagal mengambil data';
        
        // Add debugging info for 404 errors
        if (errorMessage.contains('404')) {
          errorMessage += '\n\nDetail permintaan:\nURL: 10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish'
              '\nParameter: idtool=$idTool, branchCode=$numericBranchCode';
              
          print('404 Error: $errorMessage');
          
          // Show more detailed error message with test URL
          _showDetailedErrorDialog(
            title: 'Kesalahan API (404)',
            message: 'Endpoint API tidak ditemukan. Mohon periksa konfigurasi server atau parameter.',
            technicalDetails: errorMessage,
            testUrl: testUrl
          );
        } else {
          // Show more detailed error message for other errors
          _showDetailedErrorDialog(
            title: 'Kesalahan API',
            message: errorMessage,
            technicalDetails: 'Endpoint: /CRF/rtn/validate-and-get-replenish\n'
                'ID Tool: $idTool\n'
                'Branch Code: $numericBranchCode',
            testUrl: testUrl
          );
        }
      }
    } catch (e) {
      // Enhanced error dialog with technical details
      _showDetailedErrorDialog(
        title: 'Kesalahan Jaringan',
        message: 'Terjadi kesalahan saat menghubungi server. Mohon periksa koneksi internet dan coba lagi.',
        technicalDetails: e.toString(),
        testUrl: 'http://10.10.0.223/LocalCRF/api/CRF/rtn/validate-and-get-replenish?idtool=${widget.parentIdToolController.text}&branchCode=$numericBranchCode'
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Modified _fetchDataFromApi to use the parent ID Tool
  Future<void> _fetchDataFromApi() async {
    await fetchDataFromApi(widget.parentIdToolController.text);
  }

  // Helper method to show detailed error dialog with technical info
  void _showDetailedErrorDialog({
    required String title, 
    required String message,
    String? technicalDetails,
    String? testUrl
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (technicalDetails != null) ...[
                const SizedBox(height: 16),
                const Text('Informasi Teknis:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    technicalDetails,
                    style: TextStyle(fontSize: 12, fontFamily: 'Courier', color: Colors.grey[800]),
                  ),
                ),
              ],
              if (testUrl != null && testUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'URL yang dapat diuji secara manual:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    testUrl,
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
          if (technicalDetails != null)
            TextButton(
              onPressed: () async {
                // Copy technical details to clipboard
                Clipboard.setData(ClipboardData(text: technicalDetails));
                await CustomModals.showSuccessModal(
                  context: context,
                  message: 'Informasi teknis disalin ke clipboard',
                );
              },
              child: const Text('Salin Info Teknis'),
            ),
          if (testUrl != null && testUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                // Would normally launch URL but requires url_launcher package
                // Instead we'll copy it to clipboard
                Clipboard.setData(ClipboardData(text: testUrl));
                await CustomModals.showSuccessModal(
                  context: context,
                  message: 'URL disalin ke clipboard, buka di browser untuk menguji API secara langsung',
                );
              },
              child: const Text('Salin URL Test'),
            ),
        ],
      ),
    );
  }

  Future<void> _validateNoCatridge() async {
    setState(() {
      _isValidating = true;
      noCatridgeError = ''; // Reset error message
    });
    
    // Get the catridge code
    final catridgeCode = noCatridgeController.text;
    
    // Basic validation - ensure it's not empty
    if (catridgeCode.isEmpty) {
      setState(() {
        isNoCatridgeValid = false;
        noCatridgeError = 'Nomor Catridge tidak boleh kosong';
        _isValidating = false;
      });
      return;
    }
    
    // Try to fetch data from API if ID Tool is filled
    if (widget.parentIdToolController.text.isNotEmpty) {
      await fetchDataFromApi(widget.parentIdToolController.text);
    }
    
    // Lakukan validasi sederhana di sisi client
    setState(() {
      _isValidating = false;
      isNoCatridgeValid = true;
      noCatridgeError = '';
      // Note: We don't set scan state here - it should be set only after scanning
      // because we want it to be set only after scanning
    });
  }

  Future<void> _validateNoSeal() async {
    setState(() {
      _isValidating = true;
      noSealError = ''; // Reset error message
    });
    
    // Get the seal code
    final sealCode = noSealController.text;
    
    // Basic validation - ensure it's not empty
    if (sealCode.isEmpty) {
      setState(() {
        isNoSealValid = false;
        noSealError = 'Nomor Seal tidak boleh kosong';
        _isValidating = false;
      });
      return;
    }
    
    // Lakukan validasi sederhana di sisi client
    setState(() {
      _isValidating = false;
      isNoSealValid = true;
      noSealError = '';
      // Note: We don't set scan state here - it should be set only after scanning
      // because we want it to be set only after scanning
    });
  }

  void _validateCatridgeFisik() {
    final value = catridgeFisikController.text;
    setState(() {
      isCatridgeFisikValid = value.isNotEmpty;
      catridgeFisikError = value.isEmpty ? 'Catridge Fisik tidak boleh kosong' : '';
    });
  }

  void _validateKondisiSeal(String? value) {
    setState(() {
      kondisiSeal = value;
      isKondisiSealValid = value != null;
      kondisiSealError = value == null ? 'Pilih kondisi seal' : '';
    });
  }

  void _validateKondisiCatridge(String? value) {
    setState(() {
      kondisiCatridge = value;
      isKondisiCatridgeValid = value != null;
      kondisiCatridgeError = value == null ? 'Pilih kondisi catridge' : '';
    });
  }

  void _validateBagCode() {
    setState(() {
      isBagCodeValid = bagCodeController.text.isNotEmpty;
      bagCodeError = bagCodeController.text.isEmpty ? 'Bag Code tidak boleh kosong' : '';
    });
  }

  void _validateSealCodeReturn() {
    setState(() {
      isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty;
      sealCodeReturnError = sealCodeReturnController.text.isEmpty ? 'Seal Code Return tidak boleh kosong' : '';
    });
  }

  void _validateDenom(String key, TextEditingController controller) {
    // Validate denom input
    final value = controller.text;
    if (value.isNotEmpty) {
      try {
        int.parse(value); // Ensure it's a valid number
      } catch (e) {
        setState(() {
          isDenomValid = false;
          denomError = 'Nilai denom harus berupa angka';
        });
        return;
      }
    }
    
    setState(() {
      isDenomValid = true;
      denomError = '';
    });
    
    _calculateTotals();
  }

  void _calculateTotals() {
    int totalLembar = 0;
    int totalNominal = 0;
    
    denomControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        try {
          final count = int.parse(controller.text);
          totalLembar += count;
          
          // Calculate nominal based on denom
          int denomValue = 0;
          switch (key) {
            case '100K':
              denomValue = 100000;
              break;
            case '75K':
              denomValue = 75000;
              break;
            case '50K':
              denomValue = 50000;
              break;
            case '20K':
              denomValue = 20000;
              break;
            case '10K':
              denomValue = 10000;
              break;
            case '5K':
              denomValue = 5000;
              break;
            case '2K':
              denomValue = 2000;
              break;
            case '1K':
              denomValue = 1000;
              break;
          }
          
          totalNominal += count * denomValue;
        } catch (e) {
          // Ignore parsing errors here
        }
      }
    });
    
    // Update the totals display
    // We'll implement this in the next step
  }

  @override
  void didUpdateWidget(CartridgeSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadReturnData();
  }

  void _loadReturnData() {
    print('📊 _loadReturnData() called');
    if (widget.returnData != null) {
      print('📊 Loading return data...');
      setState(() {
        _isValidating = true;
      });
      
      print('📊 Setting controller values...');
      noCatridgeController.text = widget.returnData!.catridgeCode;
      noSealController.text = widget.returnData!.catridgeSeal;
      // Clear catridgeFisik field - it will be filled by scanning
      catridgeFisikController.text = '';
      
      // If bagCode is available, use it
      if (widget.returnData!.bagCode != null) {
        bagCodeController.text = widget.returnData!.bagCode!;
      }
      
      // Set sealCodeReturn from API response
      if (widget.returnData!.sealCodeReturn != null) {
        sealCodeReturnController.text = widget.returnData!.sealCodeReturn!;
      }
      
      print('📊 Controller values set: noCatridge="${noCatridgeController.text}", noSeal="${noSealController.text}", bagCode="${bagCodeController.text}", sealCode="${sealCodeReturnController.text}"');
      
      // Reset validation state for pre-filled fields
      isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
      isNoSealValid = noSealController.text.isNotEmpty;
      isCatridgeFisikValid = false; // This needs to be scanned
      isBagCodeValid = bagCodeController.text.isNotEmpty;
      isSealCodeReturnValid = sealCodeReturnController.text.isNotEmpty;
      
      print('📊 Validation flags set: isNoCatridgeValid=$isNoCatridgeValid, isNoSealValid=$isNoSealValid, isBagCodeValid=$isBagCodeValid, isSealCodeReturnValid=$isSealCodeReturnValid');
      
      // IMPORTANT: Reset all scanned fields flags because user needs to validate by scanning
      print('📊 BEFORE RESET: scannedFields = $scannedFields');
      scannedFields.forEach((key, value) {
        scannedFields[key] = false;
      });
      print('📊 AFTER RESET: scannedFields = $scannedFields');
      
      print('Scan states reset after loading data:');
      print('Scanned fields: $scannedFields');
      print('Loaded data - noCatridge: ${noCatridgeController.text}, noSeal: ${noSealController.text}, bagCode: ${bagCodeController.text}, sealCode: ${sealCodeReturnController.text}');
      
      setState(() {
        _isValidating = false;
      });
      print('📊 _loadReturnData() completed');
    } else {
      print('📊 No return data to load');
    }
  }

  // Check if all forms are valid
  bool get isFormValid {
    bool formIsValid = isNoCatridgeValid && 
           isNoSealValid && 
           isCatridgeFisikValid && 
           isKondisiSealValid && 
           isKondisiCatridgeValid && 
           isBagCodeValid && 
           isSealCodeReturnValid && 
           isDenomValid &&
           noCatridgeController.text.isNotEmpty &&
           noSealController.text.isNotEmpty &&
           catridgeFisikController.text.isNotEmpty &&
           kondisiSeal != null &&
           kondisiCatridge != null &&
           bagCodeController.text.isNotEmpty &&
           sealCodeReturnController.text.isNotEmpty;
    
    // Periksa juga status scan
    formIsValid = formIsValid && 
                  scannedFields['noCatridge'] == true &&
                  scannedFields['noSeal'] == true &&
                  scannedFields['bagCode'] == true &&
                  scannedFields['sealCode'] == true;
           
    // Log validation status for debugging
    if (!formIsValid) {
      print('Form validation failed. Scan status: $scannedFields');
      print('Required fields scanned: noCatridge=${scannedFields['noCatridge']}, noSeal=${scannedFields['noSeal']}'); // bagCode and sealCode now use dropdown
    }
    
    return formIsValid;
  }

  // Add validation method for scanned codes
  bool _validateScannedCode(String scannedCode, TextEditingController controller) {
    // If controller is empty, any code is valid (first scan)
    if (controller.text.isEmpty) {
      return true;
    }
    
    // Otherwise, scanned code must match the existing value
    bool isValid = scannedCode == controller.text;
    print('Validating scanned code: $scannedCode against ${controller.text} - isValid: $isValid');
    return isValid;
  }
  
  // NEW: Streamlined barcode scanner for validation using stream approach
  Future<void> _openBarcodeScanner(String label, TextEditingController controller, String fieldKey) async {
    try {
      print('🎯 OPENING SCANNER: $label for field $fieldKey in section $sectionId');
      
      // Clean field label for display
      String cleanLabel = label.replaceAll(':', '').trim();
      
      // Navigate to barcode scanner with stream approach
      await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan $cleanLabel',
            fieldKey: fieldKey,
            fieldLabel: cleanLabel,
            sectionId: sectionId, // NEW: Pass section ID to scanner
            onBarcodeDetected: (String barcode) {
              // Stream will handle the result, this is just for legacy compatibility
              print('🎯 SCANNER CALLBACK: $barcode for $fieldKey in section $sectionId');
            },
          ),
        ),
      );
      
      print('🎯 SCANNER CLOSED: for $fieldKey in section $sectionId');
      
    } catch (e) {
      print('Error opening barcode scanner: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal membuka scanner: ${e.toString()}',
      );
    }
  }
  
  // REMOVED: Old scanning methods replaced with stream-based approach

  // REMOVED: _scanAndValidateField - replaced with stream approach

  @override
  Widget build(BuildContext context) {
    final bool shouldShow = widget.returnData != null || widget.title == 'Catridge 1';
    
    if (!shouldShow) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Hidden branch code field
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 0,
              width: 0,
              child: TextField(
                controller: branchCodeController,
                enabled: false,
              ),
            ),
          ),
          
          // Two-column layout for fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No Catridge input field
                    _buildInputField(
                      'No. Catridge',
                      noCatridgeController,
                      onEditingComplete: _validateNoCatridge,
                      isValid: isNoCatridgeValid,
                      errorText: noCatridgeError,
                      hasScanner: true,
                      isLoading: _isValidating,
                      readOnly: false, // Always editable
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // No Seal input field
                    _buildInputField(
                      'No. Seal',
                      noSealController,
                      onEditingComplete: _validateNoSeal,
                      isValid: isNoSealValid,
                      errorText: noSealError,
                      hasScanner: true,
                      isLoading: _isValidating,
                      readOnly: false, // Always editable
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Catridge Fisik input field
                    _buildInputField(
                      'Catridge Fisik',
                      catridgeFisikController,
                      onEditingComplete: _validateCatridgeFisik,
                      isValid: isCatridgeFisikValid,
                      errorText: catridgeFisikError,
                      isScanInput: true, // Use scan input mode for this field
                      hasScanner: true, // Add scanner
                      readOnly: false, // Pengecualian: Catridge Fisik selalu bisa diinput
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Bag Code dropdown (replaced input field with dropdown)
                    _buildDropdownFieldForBagCode(
                      'Bag Code',
                      _getAllBagCodesFromParent(),
                      selectedBagCode,
                      (String? value) {
                        setState(() {
                          selectedBagCode = value;
                          bagCodeController.text = value ?? '';
                        });
                        _validateBagCode();
                      },
                      isValid: isBagCodeValid,
                      errorText: bagCodeError,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Seal Code dropdown (replaced input field with dropdown)
                    _buildDropdownFieldForSealCode(
                      'Seal Code',
                      _getAllSealCodesFromParent(),
                      selectedSealCode,
                      (String? value) {
                        setState(() {
                          selectedSealCode = value;
                          sealCodeReturnController.text = value ?? '';
                        });
                        _validateSealCodeReturn();
                      },
                      isValid: isSealCodeReturnValid,
                      errorText: sealCodeReturnError,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Right column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Kondisi Seal dropdown
                    _buildDropdownField(
                      'Kondisi Seal',
                      kondisiSeal,
                      kondisiSealOptions,
                      (val) => _validateKondisiSeal(val),
                      isValid: isKondisiSealValid,
                      errorText: kondisiSealError,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Kondisi Catridge dropdown (reduced to two options)
                    _buildDropdownField(
                      'Kondisi Catridge',
                      kondisiCatridge,
                      kondisiCatridgeOptions,
                      (val) => _validateKondisiCatridge(val),
                      isValid: isKondisiCatridgeValid,
                      errorText: kondisiCatridgeError,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Denom fields
          const Text(
            'Denom',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          if (denomError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                denomError,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 4),
          // NEW: Two column layout - Denominasi on left, Totals on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Denominasi 1K-100K
              Expanded(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: denomControllers.entries.map((entry) {
                    return SizedBox(
                      width: 60,
                      child: TextField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: entry.key,
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                        ),
                        onEditingComplete: () => _validateDenom(entry.key, entry.value),
                        onChanged: (value) {
                          // Calculate section totals
                          _calculateSectionTotals();
                          // Trigger calculation update when denomination value changes
                          if (widget.onDenomChanged != null) {
                            widget.onDenomChanged!();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Right side - Total Lembar and Total Nominal (vertical alignment)
               SizedBox(
                 width: 200, // Fixed width to make it narrower
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     // Total Lembar
                     _buildTotalField('Total Lembar', totalLembarController),
                     
                     const SizedBox(height: 12),
                     
                     // Total Nominal
                     _buildTotalField('Total Nominal', totalNominalController),
                   ],
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    {VoidCallback? onEditingComplete,
    bool isValid = true,
    String errorText = '',
    bool hasScanner = false,
    bool isScanInput = false, 
    bool isLoading = false,
    bool readOnly = false}
  ) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;

    String fieldKey = '';
    if (label.contains('Catridge') && !label.contains('Fisik')) {
      fieldKey = 'noCatridge';
    } else if (label.contains('Seal') && !label.contains('Code')) {
      fieldKey = 'noSeal';
    } else if (label.contains('Fisik')) {
      fieldKey = 'catridgeFisik';
    } else if (label.contains('Bag')) {
      fieldKey = 'bagCode';
    } else if (label.contains('Seal Code')) {
      fieldKey = 'sealCode';
    }
    
    // Get current scan status and manual mode status
    bool isScanned = scannedFields[fieldKey] == true;
    bool isManualMode = _getFieldManualMode(fieldKey);
    bool hasAlasanRemark = _getFieldAlasanRemarkStatus(fieldKey);
    
    // Check if field is pre-filled from prepare_page (has data but not scanned)
    bool isPreFilled = _isFieldPreFilled(fieldKey);
    
    return _buildFormFieldWithManualMode(
      label, 
      controller,
      fieldKey: fieldKey,
      isValid: isValid,
      errorText: errorText,
      readOnly: readOnly,
      isScanned: isScanned,
      isManualMode: isManualMode,
      hasAlasanRemark: hasAlasanRemark,
      isPreFilled: isPreFilled,
      onScan: hasScanner ? () {
        // Open scanner for this field
        _openBarcodeScanner(label, controller, fieldKey);
      } : null,
      onManualModeToggle: isScanned ? null : () {
        _toggleFieldManualMode(fieldKey);
      },
    );
  }
  
  // Form field with scan button
  Widget _buildFormField(
    String label, 
    TextEditingController controller, 
    {bool isValid = true, 
    String errorText = '', 
    bool readOnly = false, 
    VoidCallback? onScan,
    bool isPassword = false}
  ) {
    // Mendapatkan ukuran layar untuk responsivitas
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isSmallScreen ? 40 : 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
          children: [
              // Label section - fixed width
            SizedBox(
              width: isSmallScreen ? 90 : 110,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Text(
                    '$label :',
                style: TextStyle(
                  fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                  color: isValid ? Colors.black : Colors.red,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ),
              ),
              
              // Input field with underline and scan button
            Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isValid ? Colors.grey.shade400 : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          readOnly: readOnly,
                          obscureText: isPassword,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: isValid ? Colors.black : Colors.red,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(
                              left: isSmallScreen ? 4 : 6,
                              right: isSmallScreen ? 4 : 6,
                              bottom: isSmallScreen ? 6 : 8,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                    ),
                  ),
                      ),
                      
                      // Scan button
                      if (onScan != null)
                        Container(
                          width: isSmallScreen ? 30 : 40,
                          height: isSmallScreen ? 30 : 40,
                          margin: EdgeInsets.only(
                            left: isSmallScreen ? 4 : 6,
                            bottom: isSmallScreen ? 3 : 4,
            ),
                          child: IconButton(
                icon: Icon(
                  Icons.qr_code_scanner, 
                  color: Colors.blue,
                              size: isSmallScreen ? 20 : 24,
                ),
                            padding: EdgeInsets.zero,
                            onPressed: onScan,
                          ),
              ),
                    ],
                  ),
                ),
              ),
            ],
              ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // NEW: Helper methods for manual mode per field
  bool _getFieldManualMode(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        return _noCatridgeManualMode;
      case 'noSeal':
        return _noSealManualMode;
      case 'bagCode':
        return _bagCodeManualMode;
      case 'sealCode':
        return _sealCodeManualMode;
      case 'catridgeFisik':
        return _catridgeFisikManualMode;
      default:
        return false;
    }
  }
  
  bool _getFieldAlasanRemarkStatus(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        return _noCatridgeRemarkFilled;
      case 'noSeal':
        return _noSealRemarkFilled;
      case 'bagCode':
        return _bagCodeRemarkFilled;
      case 'sealCode':
        return _sealCodeRemarkFilled;
      case 'catridgeFisik':
        return _catridgeFisikRemarkFilled;
      default:
        return false;
    }
  }
  
  // Helper method to check if field is pre-filled from prepare_page
  bool _isFieldPreFilled(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        // Field is pre-filled if it has data from returnData but hasn't been scanned
        return widget.returnData != null && 
               widget.returnData!.catridgeCode.isNotEmpty && 
               scannedFields[fieldKey] != true;
      case 'noSeal':
        // Field is pre-filled if it has data from returnData but hasn't been scanned
        return widget.returnData != null && 
               widget.returnData!.catridgeSeal.isNotEmpty && 
               scannedFields[fieldKey] != true;
      default:
        return false;
    }
  }
  
  void _toggleFieldManualMode(String fieldKey) {
    switch (fieldKey) {
      case 'noCatridge':
        _toggleNoCatridgeManualMode();
        break;
      case 'noSeal':
        _toggleNoSealManualMode();
        break;
      case 'bagCode':
        _toggleBagCodeManualMode();
        break;
      case 'sealCode':
        _toggleSealCodeManualMode();
        break;
      case 'catridgeFisik':
        _toggleCatridgeFisikManualMode();
        break;
    }
  }
  
  // NEW: Enhanced form field with manual mode icons
  Widget _buildFormFieldWithManualMode(
    String label, 
    TextEditingController controller, 
    {required String fieldKey,
    bool isValid = true, 
    String errorText = '', 
    bool readOnly = false, 
    VoidCallback? onScan,
    VoidCallback? onManualModeToggle,
    bool isScanned = false,
    bool isManualMode = false,
    bool hasAlasanRemark = false,
    bool isPreFilled = false,
    bool isPassword = false}
  ) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    // Hide underline for No. Catridge and No. Seal when pre-filled
    bool shouldHideUnderline = isPreFilled && (fieldKey == 'noCatridge' || fieldKey == 'noSeal');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: isSmallScreen ? 40 : 50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Label section - fixed width
              SizedBox(
                width: isSmallScreen ? 90 : 110,
                child: Padding(
                  padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                  child: Text(
                    '$label :',
                    style: TextStyle(
                      fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                      color: isValid ? Colors.black : Colors.red,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ),
              
              // Input field with conditional underline and icons
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: shouldHideUnderline ? null : Border(
                      bottom: BorderSide(
                        color: isValid ? Colors.grey.shade400 : Colors.red,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          readOnly: readOnly,
                          obscureText: isPassword,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: isValid ? Colors.black : Colors.red,
                          ),
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.only(
                              left: isSmallScreen ? 4 : 6,
                              right: isSmallScreen ? 4 : 6,
                              bottom: isSmallScreen ? 6 : 8,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      
                      // Manual mode icon - hanya tampil jika onManualModeToggle tidak null dan field belum di-scan
                      if (onManualModeToggle != null && !isScanned)
                        Container(
                          width: isSmallScreen ? 28 : 32,
                          height: isSmallScreen ? 28 : 32,
                          margin: EdgeInsets.only(
                            left: isSmallScreen ? 2 : 4,
                            bottom: isSmallScreen ? 2 : 3,
                          ),
                          child: GestureDetector(
                            onTap: onManualModeToggle,
                            child: Image.asset(
                              (isManualMode && hasAlasanRemark)
                                ? 'assets/images/ManualModeIcon_done.png'
                                : 'assets/images/ManualModeIcon_notdone.png',
                              width: isSmallScreen ? 20 : 24,
                              height: isSmallScreen ? 20 : 24,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.edit,
                                  size: isSmallScreen ? 20 : 24,
                                  color: (isManualMode && hasAlasanRemark) ? Colors.green : Colors.orange,
                                );
                              },
                            ),
                          ),
                        ),
                      
                      // Scan button
                      if (onScan != null)
                        Container(
                          width: isSmallScreen ? 30 : 40,
                          height: isSmallScreen ? 30 : 40,
                          margin: EdgeInsets.only(
                            left: isSmallScreen ? 2 : 3,
                            bottom: isSmallScreen ? 3 : 4,
                          ),
                          child: IconButton(
                            icon: Icon(
                              isScanned ? Icons.qr_code : Icons.qr_code_scanner,
                              color: isScanned ? Colors.green : Colors.blue,
                              size: isSmallScreen ? 18 : 22,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: onScan,
                            tooltip: isScanned ? 'Sudah di-scan' : 'Scan barcode',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // NEW: Simulate successful scan for testing
  void _simulateSuccessfulScan(String fieldKey, String label) async {
    if (mounted) {
      setState(() {
        print('🧪 [$sectionId] SIMULATING scan validation for $fieldKey');
        scannedFields[fieldKey] = true;
        
        // Set field-specific validation flags
        if (label.contains('No. Catridge')) {
          isNoCatridgeValid = true;
          noCatridgeError = '';
        } else if (label.contains('No. Seal')) {
          isNoSealValid = true;
          noSealError = '';
        } else if (label.contains('Bag Code')) {
          isBagCodeValid = true;
          bagCodeError = '';
        } else if (label.contains('Seal Code')) {
          isSealCodeReturnValid = true;
          sealCodeReturnError = '';
        } else if (label.contains('Catridge Fisik')) {
          isCatridgeFisikValid = true;
          catridgeFisikError = '';
        }
      });
      
      await CustomModals.showSuccessModal(
        context: context,
        message: '🧪 [$sectionId] $label validated (TEST)!',
      );
    }
  }

  // Simple dropdown field with validation
  Widget _buildDropdownField(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
    {bool isValid = true,
    String errorText = ''}
  ) {
    // Mendapatkan ukuran layar untuk responsivitas
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: isSmallScreen ? 90 : 110,
              child: Text(
                '$label:',
                style: TextStyle(
                  fontWeight: isValid ? FontWeight.normal : FontWeight.bold,
                  color: isValid ? Colors.black : Colors.red,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: value,
                hint: Text(
                  'Pilih $label',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                isExpanded: true,
                style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.black),
                decoration: InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isSmallScreen ? 6 : 8, 
                    horizontal: isSmallScreen ? 8 : 12
                  ),
                  isDense: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: isValid ? Colors.grey : Colors.red,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                ),
                items: options.map<DropdownMenuItem<String>>((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(
                      val,
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
        if (errorText.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: isSmallScreen ? 90 : 110, top: 4),
            child: Text(
              errorText,
              style: TextStyle(
                color: Colors.red,
                fontSize: isSmallScreen ? 10 : 12,
              ),
            ),
          ),
      ],
    );
  }

  // Add numericBranchCode getter to fix the error
  String get numericBranchCode {
    // Ensure branchCode is numeric
    if (branchCodeController.text.isEmpty || !RegExp(r'^\d+$').hasMatch(branchCodeController.text)) {
      return '1'; // Default to '1' if not numeric
    }
    return branchCodeController.text;
  }
  
  // NEW: Field-specific manual mode toggle functions (following prepare_mode pattern)
  void _toggleNoCatridgeManualMode() {
    if (!_noCatridgeManualMode) {
      _showManualModeDialog('No. Catridge', 'noCatridge');
    } else {
      setState(() {
        _noCatridgeManualMode = false;
        _noCatridgeAlasanController.clear();
        _noCatridgeRemarkController.clear();
        _noCatridgeRemarkFilled = false;
        // Reset validation to scan-based
        isNoCatridgeValid = noCatridgeController.text.isNotEmpty && scannedFields['noCatridge'] == true;
      });
    }
  }
  
  void _toggleNoSealManualMode() {
    if (!_noSealManualMode) {
      _showManualModeDialog('No. Seal', 'noSeal');
    } else {
      setState(() {
        _noSealManualMode = false;
        _noSealAlasanController.clear();
        _noSealRemarkController.clear();
        _noSealRemarkFilled = false;
        // Reset validation to scan-based
        isNoSealValid = noSealController.text.isNotEmpty && scannedFields['noSeal'] == true;
      });
    }
  }
  
  void _toggleBagCodeManualMode() {
    if (!_bagCodeManualMode) {
      _showManualModeDialog('Bag Code', 'bagCode');
    } else {
      setState(() {
        _bagCodeManualMode = false;
        _bagCodeAlasanController.clear();
        _bagCodeRemarkController.clear();
        _bagCodeRemarkFilled = false;
        // Reset validation to dropdown-based
        isBagCodeValid = selectedBagCode != null && selectedBagCode!.isNotEmpty;
      });
    }
  }
  
  void _toggleSealCodeManualMode() {
    if (!_sealCodeManualMode) {
      _showManualModeDialog('Seal Code', 'sealCode');
    } else {
      setState(() {
        _sealCodeManualMode = false;
        _sealCodeAlasanController.clear();
        _sealCodeRemarkController.clear();
        _sealCodeRemarkFilled = false;
        // Reset validation to dropdown-based
        isSealCodeReturnValid = selectedSealCode != null && selectedSealCode!.isNotEmpty;
      });
    }
  }
  
  void _toggleCatridgeFisikManualMode() {
    if (!_catridgeFisikManualMode) {
      _showManualModeDialog('Catridge Fisik', 'catridgeFisik');
    } else {
      setState(() {
        _catridgeFisikManualMode = false;
        _catridgeFisikAlasanController.clear();
        _catridgeFisikRemarkController.clear();
        _catridgeFisikRemarkFilled = false;
        // Reset validation (catridge fisik doesn't need scan validation)
        isCatridgeFisikValid = catridgeFisikController.text.isNotEmpty;
      });
    }
  }

  // Show manual mode dialog for alasan and remark input
  Future<void> _showManualModeDialog(String fieldName, String fieldType) async {
    String? initialAlasan;
    String? initialRemark;
    TextEditingController? fieldController;
    
    // Get initial values and field controller based on field type
    switch (fieldType) {
      case 'noCatridge':
        initialAlasan = _noCatridgeAlasanController.text;
        initialRemark = _noCatridgeRemarkController.text;
        fieldController = noCatridgeController;
        break;
      case 'noSeal':
        initialAlasan = _noSealAlasanController.text;
        initialRemark = _noSealRemarkController.text;
        fieldController = noSealController;
        break;
      case 'bagCode':
        initialAlasan = _bagCodeAlasanController.text;
        initialRemark = _bagCodeRemarkController.text;
        break;
      case 'sealCode':
        initialAlasan = _sealCodeAlasanController.text;
        initialRemark = _sealCodeRemarkController.text;
        break;
      case 'catridgeFisik':
        initialAlasan = _catridgeFisikAlasanController.text;
        initialRemark = _catridgeFisikRemarkController.text;
        fieldController = catridgeFisikController;
        break;
    }
    
    // Create temporary controllers for dialog
    final tempAlasanController = TextEditingController(text: initialAlasan);
    final tempRemarkController = TextEditingController(text: initialRemark);
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 600;
        
        return Dialog(
          child: Container(
            width: isSmallScreen ? screenSize.width * 0.9 : 320,
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.7,
            ),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/ManualModeIcon_notdone.png',
                        width: 20,
                        height: 20,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.edit, size: 20, color: Colors.orange);
                        },
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Detail Manual RETURN',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  
                  // Inline field display
                   if (fieldController != null) ...[
                     Row(
                       crossAxisAlignment: CrossAxisAlignment.center,
                       children: [
                         SizedBox(
                           width: 90,
                           child: Text(
                             fieldName,
                             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                           ),
                         ),
                         Text(' : ', style: TextStyle(fontSize: 12)),
                         Expanded(
                           child: Text(
                             fieldController!.text.isNotEmpty ? fieldController!.text : 'ATM XXXXXX',
                             style: TextStyle(fontSize: 12, color: fieldController!.text.isNotEmpty ? Colors.black : Colors.grey),
                           ),
                         ),
                       ],
                     ),
                     SizedBox(height: 12),
                   ],
                  
                  // Inline Alasan field with dropdown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          'Alasan',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(' : ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: tempAlasanController.text.isNotEmpty ? tempAlasanController.text : null,
                            hint: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pilih alasan',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                              ],
                            ),
                            isExpanded: true,
                            style: TextStyle(fontSize: 12, color: Colors.black),
                            items: [
                              DropdownMenuItem(value: 'Segel Tidak Terbaca', child: Text('Segel Tidak Terbaca', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Scanner Rusak', child: Text('Scanner Rusak', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'Kaset Berbeda', child: Text('Kaset Berbeda', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                tempAlasanController.text = value;
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Inline Remark field
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Remark',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                      Text(' : ', style: TextStyle(fontSize: 12)),
                      Expanded(
                        child: TextField(
                          controller: tempRemarkController,
                          decoration: InputDecoration(
                            hintText: 'Wajib diisi',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          style: TextStyle(fontSize: 12),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            'Batal',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (tempAlasanController.text.isNotEmpty && tempRemarkController.text.isNotEmpty) {
                              Navigator.of(context).pop({
                                'alasan': tempAlasanController.text,
                                'remark': tempRemarkController.text,
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Alasan dan Remark wajib diisi'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          child: Text(
                            'Simpan',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    
    // Dispose temporary controllers
    tempAlasanController.dispose();
    tempRemarkController.dispose();
    
    if (result != null) {
      setState(() {
        // Set manual mode and fill controllers based on field type
        switch (fieldType) {
          case 'noCatridge':
            _noCatridgeManualMode = true;
            _noCatridgeAlasanController.text = result['alasan']!;
            _noCatridgeRemarkController.text = result['remark']!;
            _noCatridgeRemarkFilled = true;
            isNoCatridgeValid = noCatridgeController.text.isNotEmpty;
            break;
          case 'noSeal':
            _noSealManualMode = true;
            _noSealAlasanController.text = result['alasan']!;
            _noSealRemarkController.text = result['remark']!;
            _noSealRemarkFilled = true;
            isNoSealValid = noSealController.text.isNotEmpty;
            break;
          case 'bagCode':
            _bagCodeManualMode = true;
            _bagCodeAlasanController.text = result['alasan']!;
            _bagCodeRemarkController.text = result['remark']!;
            _bagCodeRemarkFilled = true;
            isBagCodeValid = selectedBagCode != null && selectedBagCode!.isNotEmpty;
            break;
          case 'sealCode':
            _sealCodeManualMode = true;
            _sealCodeAlasanController.text = result['alasan']!;
            _sealCodeRemarkController.text = result['remark']!;
            _sealCodeRemarkFilled = true;
            isSealCodeValid = selectedSealCode != null && selectedSealCode!.isNotEmpty;
            break;
          case 'catridgeFisik':
            _catridgeFisikManualMode = true;
            _catridgeFisikAlasanController.text = result['alasan']!;
            _catridgeFisikRemarkController.text = result['remark']!;
            _catridgeFisikRemarkFilled = true;
            isCatridgeFisikValid = catridgeFisikController.text.isNotEmpty;
            break;
        }
      });
    }
  }
}

class DetailSection extends StatelessWidget {
  final ReturnHeaderResponse? returnData;
  final VoidCallback? onSubmitPressed;
  final bool isLandscape;
  final Map<String, TextEditingController> detailReturnLembarControllers;
  final Map<String, TextEditingController> detailReturnNominalControllers;
  
  const DetailSection({
    Key? key, 
    this.returnData,
    this.onSubmitPressed,
    this.isLandscape = false,
    required this.detailReturnLembarControllers,
    required this.detailReturnNominalControllers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final greenTextStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.green[700],
      fontSize: isLandscape ? 12 : 14,
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: EdgeInsets.all(isLandscape ? 8 : 12),
              child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '| Detail WSID',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isLandscape ? 14 : 16,
              ),
            ),
            SizedBox(height: isLandscape ? 6 : 8),
          _buildLabelValue('WSID', returnData?.header?.atmCode ?? ''),
          _buildLabelValue('Bank', returnData?.header?.codeBank ?? returnData?.header?.namaBank ?? ''),
          _buildLabelValue('Lokasi', returnData?.header?.lokasi ?? ''),
          _buildLabelValue('Jenis Mesin', returnData?.header?.jnsMesin ?? ''),
          _buildLabelValue('ATM Type', returnData?.header?.idTypeAtm ?? returnData?.header?.typeATM ?? ''),
          _buildLabelValue('Tgl. Unload', returnData?.header?.timeSTReturn ?? ''),
          const Divider(height: 24, thickness: 1),
          const Text(
            '| Detail Return',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Seluruh Lembar (Denom)',
                      style: greenTextStyle,
                    ),
                    const SizedBox(height: 8),
                    ..._buildDenomFields(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Seluruh Nominal (Denom)',
                      style: greenTextStyle,
                    ),
                    const SizedBox(height: 8),
                    ..._buildNominalFields(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              Text(
                'Grand Total :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Text('Rp'),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: returnData != null ? onSubmitPressed : null,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Submit Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDenomFields() {
    final denomLabels = ['100K', '75K', '50K', '20K', '10K', '5K', '2K', '1K'];
    return denomLabels
        .map(
          (label) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: detailReturnLembarControllers[label],
                    readOnly: true, // Make it read-only
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      // Use underlined style for consistency
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      // Add visual indication that it's read-only
                      fillColor: Color(0xFFF5F5F5),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Lembar'),
              ],
            ),
          ),
        )
        .toList();
  }

  List<Widget> _buildNominalFields() {
    final denomLabels = ['100K', '75K', '50K', '20K', '10K', '5K', '2K', '1K'];
    return denomLabels
        .map(
          (label) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 50,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const Text(': Rp'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: detailReturnNominalControllers[label],
                    readOnly: true, // Make it read-only
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      // Use underlined style for consistency
                      border: UnderlineInputBorder(),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.green),
                      ),
                      // Add visual indication that it's read-only
                      fillColor: Color(0xFFF5F5F5),
                      filled: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
