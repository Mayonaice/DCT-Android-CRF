import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/tl_header_widget.dart';
import '../services/profile_service.dart';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';
import '../widgets/face_recognition_widget.dart';
import '../widgets/custom_modals.dart';
import '../services/api_service.dart';

class TLApprovalSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> qrData;
  final String userName;
  final String branchName;

  const TLApprovalSummaryScreen({
    Key? key,
    required this.qrData,
    required this.userName,
    required this.branchName,
  }) : super(key: key);

  @override
  State<TLApprovalSummaryScreen> createState() => _TLApprovalSummaryScreenState();
}

class _TLApprovalSummaryScreenState extends State<TLApprovalSummaryScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  bool _isProcessing = false;
  String _action = '';
  Map<String, dynamic> _details = {};
  List<dynamic> _catridges = [];
  int _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CRF_TL
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _parseQRData();
  }

  void _parseQRData() {
    debugPrint('🔍 [TL_APPROVAL] Parsing QR data...');
    debugPrint('🔍 [TL_APPROVAL] QR Data keys: ${widget.qrData.keys.toList()}');
    
    _action = widget.qrData['action']?.toString() ?? '';
    _details = widget.qrData['details'] as Map<String, dynamic>? ?? {};
    _catridges = widget.qrData['catridges'] as List<dynamic>? ?? [];
    
    // Calculate total amount from catridges
    _totalAmount = 0;
    for (var catridge in _catridges) {
      final qty = int.tryParse(catridge['qty']?.toString() ?? '0') ?? 0;
      _totalAmount += qty;
    }
    
    debugPrint('🔍 [TL_APPROVAL] Parsed data:');
    debugPrint('   - Action: $_action');
    debugPrint('   - Details: $_details');
    debugPrint('   - Catridges count: ${_catridges.length}');
    debugPrint('   - Total amount: $_totalAmount');
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Future<void> _showFaceRecognitionAndApprove() async {
    if (_isProcessing) return;
    
    debugPrint('🎭 [FACE_RECOGNITION] Starting face recognition for approval...');
    
    // Get user ID for face verification
    final userData = await _authService.getUserData();
    final userId = userData?['userId'] ?? userData?['userID'] ?? userData?['nik'] ?? '';
    
    if (userId.isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'User ID not found. Please login again.',
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
      // Face verification successful, proceed to API call
      debugPrint('✅ [FACE_RECOGNITION] Face verification successful, proceeding to API call');
      await _processApproval();
    } else {
      // Verification failed or cancelled
      await CustomModals.showFailedModal(
        context: context,
        message: 'Face verification failed. Please try again.',
      );
    }
  }

  Future<void> _processApproval() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      debugPrint('🚀 [API_APPROVAL] Starting approval process for action: $_action');
      
      if (_action == 'PREPARE') {
        await _processPrepareApproval();
      } else if (_action == 'RETURN') {
        await _processReturnApproval();
      } else {
        throw Exception('Unknown action: $_action');
      }
      
      await CustomModals.showSuccessModal(
        context: context,
        message: 'Approval berhasil! Data telah diproses.',
      );
      
      // Navigate back to home
      Navigator.of(context).popUntil((route) => route.isFirst);
      
    } catch (e) {
      debugPrint('❌ [API_APPROVAL] Error during approval: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Approval gagal: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processPrepareApproval() async {
    debugPrint('🔧 [PREPARE_APPROVAL] Processing PREPARE approval...');
    
    // Call planning update API
    final planningResponse = await _apiService.updatePlanning(
      idTool: int.tryParse(_details['wsid'] ?? '0') ?? 0,
      cashierCode: 'TL_APPROVAL',
      spvTLCode: 'TL_SUPERVISOR',
      tableCode: 'PREPARE',
    );
    
    if (!planningResponse.success) {
      throw Exception('Planning update failed: ${planningResponse.message}');
    }
    
    // Call catridge insert API for each catridge
    for (var catridge in _catridges) {
      final response = await _apiService.insertAtmCatridge(
        idTool: catridge['idTool'] as int,
        bagCode: catridge['bagCode'] as String,
        catridgeCode: catridge['catridgeCode'] as String,
        sealCode: catridge['sealCode'] as String,
        catridgeSeal: catridge['catridgeSeal'] as String,
        denomCode: catridge['denomCode'] as String,
        qty: catridge['qty'] as String,
        userInput: catridge['userInput'] as String,
        sealReturn: catridge['sealReturn'] as String,
        scanCatStatus: catridge['scanCatStatus'] as String,
        scanCatStatusRemark: catridge['scanCatStatusRemark'] as String,
        scanSealStatus: catridge['scanSealStatus'] as String,
        scanSealStatusRemark: catridge['scanSealStatusRemark'] as String,
        difCatAlasan: catridge['difCatAlasan'] as String,
        difCatRemark: catridge['difCatRemark'] as String,
        typeCatridgeTrx: 'PREPARE',
      );
      
      if (!response.success) {
        throw Exception('Catridge insert failed: ${response.message}');
      }
    }
    
    debugPrint('✅ [PREPARE_APPROVAL] PREPARE approval completed successfully');
  }

  Future<void> _processReturnApproval() async {
    debugPrint('🔧 [RETURN_APPROVAL] Processing RETURN approval...');
    
    // Call return catridge API for each catridge
    for (var catridge in _catridges) {
      final response = await _apiService.insertReturnCatridge(
        IdTool: catridge['IdTool'] as String,
        BagCode: catridge['BagCode'] as String,
        CatridgeCode: catridge['CatridgeCode'] as String,
        SealCode: catridge['SealCode'] as String,
        CatridgeSeal: catridge['CatridgeSeal'] as String,
        DenomCode: catridge['DenomCode'] as String,
        Qty: catridge['Qty'] as String,
        UserInput: catridge['UserInput'] as String,
        IsBalikKaset: catridge['IsBalikKaset'] as String,
        CatridgeCodeOld: catridge['CatridgeCodeOld'] as String,
        ScanCatStatus: catridge['ScanCatStatus'] as String,
        ScanCatStatusRemark: catridge['ScanCatStatusRemark'] as String,
        ScanSealStatus: catridge['ScanSealStatus'] as String,
        ScanSealStatusRemark: catridge['ScanSealStatusRemark'] as String,
      );
      
      if (!response.success) {
        throw Exception('Return catridge insert failed: ${response.message}');
      }
    }
    
    debugPrint('✅ [RETURN_APPROVAL] RETURN approval completed successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header menggunakan TLHeaderWidget
            TLHeaderWidget(
              userName: widget.userName,
              branchName: widget.branchName,
              greetingText: 'Konfirmasi Approve TLSPV',
              profileService: _profileService,
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Back button dan title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Konfirmasi Approve TLSPV',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Summary Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID CRF
                          Row(
                            children: [
                              const Text(
                                'ID CRF : ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _details['wsid']?.toString() ?? '5774146',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // WSID dan Bank
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'WSID',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(':', style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Text(
                                          _details['wsid']?.toString() ?? 'BCA-1223',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Bank',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(':', style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _details['bank']?.toString() ?? 'Bank Central Asia',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Lokasi
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lokasi',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              const Text(':', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _details['lokasi']?.toString() ?? 'Jl. Bandung Raya No.1,\nJawa Barat',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // ATM Type dan Jumlah Kaset
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'ATM Type',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(':', style: TextStyle(fontSize: 14)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _details['atmType']?.toString() ?? 'HYOSUNG KHUSUS B',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Jumlah Kaset
                          Row(
                            children: [
                              const Text(
                                'Jumlah Kaset',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              const Text(':', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(
                                _action == 'PREPARE' 
                                  ? (_details['jumlahKaset']?.toString() ?? '1')
                                  : _catridges.length.toString(),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Total
                          Row(
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                              const Text(':', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(
                                'Rp ${_formatCurrency(_totalAmount)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Approve Data Button
                    Container(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _showFaceRecognitionAndApprove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: _isProcessing
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            )
                          : const Text(
                              'Approve Data',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
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
    );
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
}