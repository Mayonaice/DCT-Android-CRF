import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/prepare_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';
import '../screens/profile_menu_screen.dart';
import '../widgets/qr_code_generator_widget.dart';

class PrepareSummaryPage extends StatefulWidget {
  final ATMPrepareReplenishData? prepareData;
  final List<DetailCatridgeItem> catridgeData;
  final List<Map<String, dynamic>> divertData;
  final Map<String, dynamic>? pocketData;

  const PrepareSummaryPage({
    Key? key,
    required this.prepareData,
    required this.catridgeData,
    required this.divertData,
    this.pocketData,
  }) : super(key: key);

  @override
  State<PrepareSummaryPage> createState() => _PrepareSummaryPageState();
}

class _PrepareSummaryPageState extends State<PrepareSummaryPage> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _tlNikController = TextEditingController();
  final TextEditingController _tlPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String _userName = '';
  String _branchName = '';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    debugPrint('🚀 [PREPARE_SUMMARY] InitState called');
    debugPrint('🔧 [PREPARE_SUMMARY] Environment Info:');
    debugPrint('   - Debug mode: ${kDebugMode}');
    debugPrint('   - Platform: ${defaultTargetPlatform.name}');
    debugPrint('   - Timestamp: ${DateTime.now().toIso8601String()}');
    debugPrint('   - Widget hash: ${hashCode}');


    
    debugPrint('📊 [PREPARE_SUMMARY] Widget data received:');
    debugPrint('   - Prepare data: ${widget.prepareData != null ? "Available" : "Null"}');
    debugPrint('   - Catridge items: ${widget.catridgeData.length}');
    debugPrint('   - Divert items: ${widget.divertData.length}');
    debugPrint('   - Pocket data: ${widget.pocketData != null ? "Available" : "Null"}');
    
    debugPrint('✅ [PREPARE_SUMMARY] Services initialized');
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      debugPrint('📱 [LOAD_USER_DATA] Starting user data loading...');
      final userData = await _authService.getUserData();
      
      debugPrint('👤 [LOAD_USER_DATA] User data loaded:');
      debugPrint('   - Raw data keys: ${userData?.keys.toList()}');
      debugPrint('   - userName field: ${userData?['userName']}');
      debugPrint('   - username field: ${userData?['username']}');
      debugPrint('   - branchName field: ${userData?['branchName']}');
      debugPrint('   - branch field: ${userData?['branch']}');
      
      if (userData != null) {
        final userName = userData['userName'] ?? userData['username'] ?? 'User';
        final branchName = userData['branchName'] ?? userData['branch'] ?? 'Branch';
        
        debugPrint('   - Final userName: $userName');
        debugPrint('   - Final branchName: $branchName');
        
        setState(() {
          _userData = userData;
          _userName = userName;
          _branchName = branchName;
        });
        
        debugPrint('✅ [LOAD_USER_DATA] User data loaded successfully, UI updated');
      } else {
        debugPrint('⚠️ [LOAD_USER_DATA] User data is null');
      }
    } catch (e) {
      debugPrint('❌ [LOAD_USER_DATA] Error loading user data: ${e.toString()}');
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchSummaryData() async {
    debugPrint('🔄 [FETCH_SUMMARY] Refreshing summary data...');
    // Refresh summary data if needed
    await _loadUserData();
    // Add any additional data refresh logic here
    debugPrint('✅ [FETCH_SUMMARY] Summary data refresh completed');
  }

  @override
  void dispose() {
    debugPrint('🗑️ [DISPOSE] Disposing PrepareSummaryPage resources');
    _tlNikController.dispose();
    _tlPasswordController.dispose();
    debugPrint('✅ [DISPOSE] Controllers disposed successfully');
    super.dispose();
  }

  List<CatridgeQRData> _prepareCatridgeQRData() {
    debugPrint('🔧 [QR_DATA] Preparing catridge QR data...');
    List<CatridgeQRData> qrDataList = [];
    
    for (var catridge in widget.catridgeData) {
      final qrData = CatridgeQRData(
        idTool: widget.prepareData?.atmCode ?? '0',
        bagCode: catridge.bagCode ?? '',
        catridgeCode: catridge.noCatridge ?? '',
        sealCode: catridge.sealCode ?? '',
        catridgeSeal: catridge.sealCatridge ?? '',
        denomCode: catridge.denom ?? '',
        qty: catridge.value?.toString() ?? '0',
        userInput: 'PREPARE',
        sealReturn: '',
        typeCatridgeTrx: 'PREPARE',
        tableCode: 'PREPARE',
        warehouseCode: '',
        operatorId: '',
        operatorName: '',
      );
      qrDataList.add(qrData);
      debugPrint('   - Added catridge: ${catridge.noCatridge}');
    }
    
    debugPrint('✅ [QR_DATA] Prepared ${qrDataList.length} catridge QR data items');
    return qrDataList;
  }

  Future<void> _validateTLAndSubmit() async {
    debugPrint('🔘 [VALIDATE_TL] Submit button pressed!');
    debugPrint('📝 [VALIDATE_TL] Checking TL credentials...');
    debugPrint('   - NIK length: ${_tlNikController.text.length}');
    debugPrint('   - Password length: ${_tlPasswordController.text.length}');
    
    if (_tlNikController.text.isEmpty || _tlPasswordController.text.isEmpty) {
      debugPrint('❌ [VALIDATE_TL] Validation failed: Empty NIK or Password');
      await _showErrorDialog('NIK dan Password TL harus diisi');
      return;
    }
    
    debugPrint('🔄 [VALIDATE_TL] Setting submitting state to true');
    debugPrint('📊 [STATE_MANAGEMENT] Current widget state before update:');
    debugPrint('   - _isSubmitting: $_isSubmitting');
    debugPrint('   - _userName: $_userName');
    debugPrint('   - _branchName: $_branchName');
    debugPrint('   - _userData keys: ${_userData?.keys.toList()}');
    
    setState(() { _isSubmitting = true; });
    debugPrint('📊 [STATE_MANAGEMENT] State after update: _isSubmitting = $_isSubmitting');
    
    try {
      // Validate TL credentials
      debugPrint('🔐 [VALIDATE_TL] Calling validateTLSupervisor API...');
      debugPrint('🌐 [VALIDATE_TL_API] Endpoint: POST /validateTLSupervisor');
      debugPrint('📤 [VALIDATE_TL_API] Request Parameters:');
      debugPrint('   - nik: ${_tlNikController.text}');
      debugPrint('   - password: [HIDDEN]');
      debugPrint('⏰ [VALIDATE_TL_API] Request timestamp: ${DateTime.now().toIso8601String()}');
      
      final startTime = DateTime.now();
      final tlResponse = await _apiService.validateTLSupervisor(
        nik: _tlNikController.text,
        password: _tlPasswordController.text,
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      debugPrint('📥 [VALIDATE_TL_API] Response:');
      debugPrint('   - success: ${tlResponse.success}');
      debugPrint('   - message: ${tlResponse.message}');
      debugPrint('⏰ [VALIDATE_TL_API] Response timestamp: ${endTime.toIso8601String()}');
      debugPrint('⏱️ [VALIDATE_TL_API] Duration: ${duration.inMilliseconds}ms');
      
      if (tlResponse.success) {
        debugPrint('✅ [VALIDATE_TL] TL validation successful, proceeding to submit data');
        // Submit prepare data
        await _submitPrepareData();
      } else {
        debugPrint('❌ [VALIDATE_TL] TL validation failed: ${tlResponse.message}');
        await _showErrorDialog(tlResponse.message ?? 'Validasi TL gagal');
      }
    } catch (e) {
      debugPrint('💥 [VALIDATE_TL] Exception during TL validation: ${e.toString()}');
      debugPrint('📍 [VALIDATE_TL] Stack trace: ${StackTrace.current}');
      await _showErrorDialog('Error validasi TL: ${e.toString()}');
    } finally {
      debugPrint('🔄 [VALIDATE_TL] Setting submitting state to false');
      debugPrint('📊 [STATE_MANAGEMENT] Resetting state: _isSubmitting from $_isSubmitting to false');
      setState(() { _isSubmitting = false; });
      debugPrint('✅ [STATE_MANAGEMENT] State reset completed: _isSubmitting = $_isSubmitting');
    }
  }

  Future<void> _submitPrepareData() async {
    final processStartTime = DateTime.now();
    try {
      debugPrint('🚀 [PREPARE_SUMMARY] Starting submit prepare data process');
      debugPrint('⏰ [PREPARE_SUMMARY] Process start time: ${processStartTime.toIso8601String()}');
      debugPrint('🌐 [PREPARE_SUMMARY] Network check: Attempting connectivity verification...');
      debugPrint('📱 [PREPARE_SUMMARY] Device info: Platform ${defaultTargetPlatform.name}, Debug: ${kDebugMode}');
      
      // Get user data
      debugPrint('📱 [PREPARE_SUMMARY] Getting user data from AuthService...');
      final userData = await _authService.getUserData();
      final userId = userData?['userId']?.toString() ?? userData?['userID']?.toString() ?? '';
      final userName = userData?['userName']?.toString() ?? userData?['username']?.toString() ?? '';
      
      debugPrint('👤 [PREPARE_SUMMARY] User Data Retrieved:');
      debugPrint('   - userId: $userId');
      debugPrint('   - userName: $userName');
      debugPrint('   - Full userData keys: ${userData?.keys.toList()}');
      
      // Get planning ID and ATM ID from prepareData
      final planningId = widget.prepareData?.id ?? 0;
      final atmCode = widget.prepareData?.atmCode ?? '';
      final cashierCode = widget.prepareData?.cashierCode ?? '';
      final tableCode = widget.prepareData?.tableCode ?? '';
      
      debugPrint('📋 [PREPARE_SUMMARY] Prepare Data Info:');
      debugPrint('   - planningId: $planningId');
      debugPrint('   - atmCode: $atmCode');
      debugPrint('   - cashierCode: $cashierCode');
      debugPrint('   - tableCode: $tableCode');
      
      // Debug data counts and details
      debugPrint('📊 [PREPARE_SUMMARY] Data Counts:');
      debugPrint('   - Catridge items: ${widget.catridgeData.length}');
      debugPrint('   - Divert items: ${widget.divertData.length}');
      debugPrint('   - Pocket data: ${widget.pocketData != null ? "Available" : "None"}');
      
      // Debug detailed catridge data
      debugPrint('💰 [PREPARE_SUMMARY] Catridge Data Details:');
      for (int i = 0; i < widget.catridgeData.length; i++) {
        final item = widget.catridgeData[i];
        debugPrint('   Catridge ${i + 1}:');
        debugPrint('     - noCatridge: ${item.noCatridge}');
        debugPrint('     - sealCatridge: ${item.sealCatridge}');
        debugPrint('     - denom: ${item.denom}');
        debugPrint('     - total: ${item.total}');
        debugPrint('     - value: ${item.value}');
        debugPrint('     - bagCode: ${item.bagCode}');
        debugPrint('     - sealCode: ${item.sealCode}');
        debugPrint('     - sealReturn: ${item.sealReturn}');
      }
      
      // Debug detailed divert data
      debugPrint('🔄 [PREPARE_SUMMARY] Divert Data Details:');
      for (int i = 0; i < widget.divertData.length; i++) {
        final item = widget.divertData[i];
        debugPrint('   Divert ${i + 1}:');
        debugPrint('     - bagCode: ${item['bagCode']}');
        debugPrint('     - sealCode: ${item['sealCode']}');
        debugPrint('     - sealReturn: ${item['sealReturn']}');
        debugPrint('     - denomAmount: ${item['denomAmount']}');
        debugPrint('     - value: ${item['value']}');
        debugPrint('     - noAlasan: ${item['noAlasan']}');
        debugPrint('     - noRemark: ${item['noRemark']}');
      }
      
      // Debug pocket data
      if (widget.pocketData != null) {
        debugPrint('👝 [PREPARE_SUMMARY] Pocket Data Details:');
        debugPrint('     - bagCode: ${widget.pocketData!['bagCode']}');
        debugPrint('     - sealCode: ${widget.pocketData!['sealCode']}');
        debugPrint('     - sealReturn: ${widget.pocketData!['sealReturn']}');
        debugPrint('     - denomAmount: ${widget.pocketData!['denomAmount']}');
        debugPrint('     - value: ${widget.pocketData!['value']}');
        debugPrint('     - noAlasan: ${widget.pocketData!['noAlasan']}');
        debugPrint('     - noRemark: ${widget.pocketData!['noRemark']}');
      }
      
      // Insert catridge data (main catridge items) - STEP 2
      debugPrint('💾 [PREPARE_SUMMARY] Starting catridge data insertion...');
      await _insertCatridgeData(widget.catridgeData, 'C', planningId, atmCode, userId);
      
      // Insert divert data if exists
      if (widget.divertData.isNotEmpty) {
        debugPrint('💾 [PREPARE_SUMMARY] Starting divert data insertion...');
        await _insertCatridgeData(widget.divertData, 'D', planningId, atmCode, userId);
      } else {
        debugPrint('ℹ️ [PREPARE_SUMMARY] No divert data to insert');
      }
      
      // Insert pocket data if exists
      if (widget.pocketData != null) {
        debugPrint('💾 [PREPARE_SUMMARY] Starting pocket data insertion...');
        await _insertCatridgeData([widget.pocketData!], 'P', planningId, atmCode, userId);
      } else {
        debugPrint('ℹ️ [PREPARE_SUMMARY] No pocket data to insert');
      }
      
      // Update planning status - STEP 3 (moved to last)
      debugPrint('🔄 [PREPARE_SUMMARY] Calling updatePlanning API...');
      debugPrint('🌐 [UPDATE_PLANNING] Endpoint: POST /updatePlanning');
      debugPrint('📤 [UPDATE_PLANNING] Request Parameters:');
      debugPrint('   - idTool: $planningId');
      debugPrint('   - cashierCode: $cashierCode');
      debugPrint('   - spvTLCode: $userId');
      debugPrint('   - tableCode: $tableCode');
      debugPrint('⏰ [UPDATE_PLANNING] Request timestamp: ${DateTime.now().toIso8601String()}');
      
      final startTime = DateTime.now();
      final updateResponse = await _apiService.updatePlanning(
        idTool: planningId,
        cashierCode: cashierCode,
        spvTLCode: userId,
        tableCode: tableCode,
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      debugPrint('📥 [UPDATE_PLANNING] Response:');
      debugPrint('   - success: ${updateResponse.success}');
      debugPrint('   - message: ${updateResponse.message}');
      debugPrint('⏰ [UPDATE_PLANNING] Response timestamp: ${endTime.toIso8601String()}');
      debugPrint('⏱️ [UPDATE_PLANNING] Duration: ${duration.inMilliseconds}ms');
      
      if (!updateResponse.success) {
        debugPrint('❌ [UPDATE_PLANNING] Failed: ${updateResponse.message}');
        throw Exception(updateResponse.message);
      }
      
      debugPrint('✅ [UPDATE_PLANNING] Success!');
      
      debugPrint('🎉 [PREPARE_SUMMARY] All data inserted successfully!');
      
      final processEndTime = DateTime.now();
      final totalDuration = processEndTime.difference(processStartTime);
      
      debugPrint('📊 [PREPARE_SUMMARY] Process Summary:');
      debugPrint('   - Total catridge items processed: ${widget.catridgeData.length}');
      debugPrint('   - Total divert items processed: ${widget.divertData.length}');
      debugPrint('   - Pocket data processed: ${widget.pocketData != null ? 1 : 0}');
      debugPrint('   - Total API calls made: ${1 + widget.catridgeData.length + widget.divertData.length + (widget.pocketData != null ? 1 : 0)}');
      debugPrint('⏰ [PREPARE_SUMMARY] Process end time: ${processEndTime.toIso8601String()}');
      debugPrint('⏱️ [PREPARE_SUMMARY] Total process duration: ${totalDuration.inMilliseconds}ms (${totalDuration.inSeconds}s)');
      
      await _showSuccessDialog(updateResponse.message);
      
      // Navigate back to previous screens
      debugPrint('🔄 [NAVIGATION] Navigating back to first screen...');
      Navigator.of(context).popUntil((route) => route.isFirst);
      debugPrint('✅ [NAVIGATION] Navigation completed');
    } catch (e) {
      final processEndTime = DateTime.now();
      final totalDuration = processEndTime.difference(processStartTime);
      
      debugPrint('💥 [PREPARE_SUMMARY] Error in submit process: ${e.toString()}');
      debugPrint('📍 [PREPARE_SUMMARY] Stack trace: ${StackTrace.current}');
      debugPrint('⏰ [PREPARE_SUMMARY] Error occurred at: ${processEndTime.toIso8601String()}');
      debugPrint('⏱️ [PREPARE_SUMMARY] Process duration before error: ${totalDuration.inMilliseconds}ms (${totalDuration.inSeconds}s)');
      await _showErrorDialog(e.toString());
    }
  }
  
  Future<void> _insertCatridgeData(List<dynamic> data, String type, int planningId, String atmCode, String userId) async {
    debugPrint('🔄 [INSERT_CATRIDGE_DATA] Starting batch insertion:');
    debugPrint('   - Items count: ${data.length}');
    debugPrint('   - Type: $type');
    debugPrint('   - Planning ID: $planningId');
    debugPrint('   - ATM Code: $atmCode');
    debugPrint('   - User ID: $userId');
    
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      
      debugPrint('📦 [INSERT_CATRIDGE_DATA] Processing item ${i + 1}/${data.length}:');
      
      // Handle different data types for debug logging
      if (item is DetailCatridgeItem) {
        debugPrint('   - Bag Code: ${item.bagCode ?? ''}');
        debugPrint('   - Seal Code: ${item.sealCode ?? ''}');
        debugPrint('   - Value: ${item.value?.toString() ?? '0'}');
      } else if (item is Map<String, dynamic>) {
        debugPrint('   - Bag Code: ${item['bagCode']?.toString() ?? ''}');
        debugPrint('   - Seal Code: ${item['sealCode']?.toString() ?? ''}');
        debugPrint('   - Value: ${item['value']?.toString() ?? '0'}');
      }
      
      await _insertCatridge(item, type, planningId, atmCode, userId);
    }
    
    debugPrint('🎉 [INSERT_CATRIDGE_DATA] All items processed successfully!');
  }
  
  Future<void> _insertCatridge(dynamic item, String type, int planningId, String atmCode, String userId) async {
    int retryCount = 0;
    const maxRetries = 3;
    
    // Extract and log all parameters
    String bagCode = '';
    String sealCode = '';
    String sealReturn = '';
    String denomAmount = '0';
    String value = '0';
    String noAlasan = '';
    String noRemark = '';
    
    // Handle different data types (DetailCatridgeItem vs Map)
    String scanCatStatus = 'TEST';
    String scanCatStatusRemark = 'TEST';
    String scanSealStatus = 'TEST';
    String scanSealStatusRemark = 'TEST';
    String catridgeSeal = '';
    String catridgeCode = '';
    
    if (item is DetailCatridgeItem) {
      bagCode = item.bagCode ?? '';
      sealCode = item.sealCode ?? '';
      sealReturn = item.sealReturn ?? '';
      denomAmount = item.denom ?? '0';
      value = item.value?.toString() ?? '0';
      catridgeCode = item.noCatridge ?? '';
      catridgeSeal = item.sealCatridge ?? '';
      noAlasan = '';
      noRemark = '';
    } else if (item is Map<String, dynamic>) {
      bagCode = item['bagCode']?.toString() ?? '';
      sealCode = item['sealCode']?.toString() ?? '';
      sealReturn = item['sealReturn']?.toString() ?? '';
      denomAmount = item['denomAmount']?.toString() ?? '0';
      value = item['value']?.toString() ?? '0';
      catridgeCode = item['noCatridge']?.toString() ?? '';
      catridgeSeal = item['sealCatridge']?.toString() ?? '';
      noAlasan = item['noAlasan']?.toString() ?? '';
      noRemark = item['noRemark']?.toString() ?? '';
      scanCatStatus = item['scanCatStatus']?.toString() ?? 'TEST';
      scanCatStatusRemark = item['scanCatStatusRemark']?.toString() ?? 'TEST';
      scanSealStatus = item['scanSealStatus']?.toString() ?? 'TEST';
      scanSealStatusRemark = item['scanSealStatusRemark']?.toString() ?? 'TEST';
    }
    
    debugPrint('🔧 [INSERT_CATRIDGE] Preparing API call with parameters:');
     debugPrint('🌐 [INSERT_CATRIDGE_API] Endpoint: POST /insertAtmCatridge');
     debugPrint('📤 [INSERT_CATRIDGE_API] Request Parameters:');
     debugPrint('   - idTool: $planningId');
     debugPrint('   - bagCode: $bagCode');
     debugPrint('   - catridgeCode: $catridgeCode');
     debugPrint('   - sealCode: $sealCode');
     debugPrint('   - catridgeSeal: $catridgeSeal');
     debugPrint('   - denomCode: $denomAmount');
     debugPrint('   - qty: $value');
     debugPrint('   - userInput: $userId');
     debugPrint('   - sealReturn: $sealReturn');
     debugPrint('   - scanCatStatus: $scanCatStatus');
     debugPrint('   - scanCatStatusRemark: $scanCatStatusRemark');
     debugPrint('   - scanSealStatus: $scanSealStatus');
     debugPrint('   - scanSealStatusRemark: $scanSealStatusRemark');
     debugPrint('   - difCatAlasan: $noAlasan');
     debugPrint('   - difCatRemark: $noRemark');
     debugPrint('   - typeCatridgeTrx: $type');
     debugPrint('⏰ [INSERT_CATRIDGE_API] Request timestamp: ${DateTime.now().toIso8601String()}');
    
    while (retryCount < maxRetries) {
      try {
         debugPrint('🔄 [INSERT_CATRIDGE] API call attempt ${retryCount + 1}/$maxRetries');
         
         final startTime = DateTime.now();
         final response = await _apiService.insertAtmCatridge(
           idTool: planningId,
           bagCode: bagCode,
           catridgeCode: catridgeCode,
           sealCode: sealCode,
           catridgeSeal: catridgeSeal,
           denomCode: denomAmount,
           qty: value,
           userInput: userId,
           sealReturn: sealReturn,
           scanCatStatus: scanCatStatus,
           scanCatStatusRemark: scanCatStatusRemark,
           scanSealStatus: scanSealStatus,
           scanSealStatusRemark: scanSealStatusRemark,
           difCatAlasan: noAlasan,
           difCatRemark: noRemark,
           typeCatridgeTrx: type,
         );
         final endTime = DateTime.now();
         final duration = endTime.difference(startTime);
         
         debugPrint('📥 [INSERT_CATRIDGE] API Response:');
         debugPrint('   - success: ${response.success}');
         debugPrint('   - message: ${response.message}');
         debugPrint('⏰ [INSERT_CATRIDGE] Response timestamp: ${endTime.toIso8601String()}');
         debugPrint('⏱️ [INSERT_CATRIDGE] Duration: ${duration.inMilliseconds}ms');
        
        if (response.success) {
          debugPrint('✅ [INSERT_CATRIDGE] Insert successful!');
          break; // Success, exit retry loop
        } else {
          debugPrint('❌ [INSERT_CATRIDGE] Insert failed: ${response.message}');
          throw Exception(response.message ?? response.message);
        }
      } catch (e) {
        retryCount++;
        debugPrint('💥 [INSERT_CATRIDGE] Exception on attempt $retryCount: ${e.toString()}');
        if (retryCount >= maxRetries) {
          debugPrint('🚫 [INSERT_CATRIDGE] Max retries reached, throwing exception');
          throw Exception('${e.toString()}');
        }
        // Wait before retry
        debugPrint('⏳ [INSERT_CATRIDGE] Waiting 1s before retry...');
        await Future.delayed(Duration(seconds: 1));
      }
    }
  }

  Future<void> _showErrorDialog(String message) async {
    debugPrint('❌ [DIALOG] Showing error dialog: $message');
    return CustomModals.showFailedModal(
      context: context,
      message: message,
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    debugPrint('🎉 [DIALOG] Showing success dialog: $message');
    return CustomModals.showSuccessModal(
      context: context,
      message: message,
    );
  }

  // Helper method to get appropriate title for catridge section based on item index
  String _getCatridgeSectionTitle(DetailCatridgeItem catridge, int index) {
    if (catridge.index >= 200) {
      // Pocket section (index 200+)
      return 'Pocket';
    } else if (catridge.index >= 100) {
      // Divert sections (index 100-102)
      int divertNumber = catridge.index - 99; // 100->1, 101->2, 102->3
      return 'Divert $divertNumber';
    } else {
      // Main catridge sections (index 1-10)
      return 'Catridge ${index + 1}';
    }
  }

  Widget _buildCatridgeSection(DetailCatridgeItem catridge, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCatridgeSectionTitle(catridge, index),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Layout 2 kolom untuk field catridge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom 1
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('No. Catridge', catridge.noCatridge),
                    _buildCatridgeField('Seal Catridge', catridge.sealCatridge),
                    _buildCatridgeField('Denom', catridge.denom),
                    _buildCatridgeField('Bag Code', catridge.bagCode),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 160,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Kolom 2
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('Total', catridge.total),
                    _buildCatridgeField('Value', catridge.value.toString()),
                    _buildCatridgeField('Seal Code', catridge.sealCode),
                    _buildCatridgeField('Seal Code Return', catridge.sealReturn),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatridgeField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivertSection(Map<String, dynamic> divert, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Divert ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Layout 2 kolom untuk field divert
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom 1
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('No. Catridge', divert['noCatridge'] ?? ''),
                    _buildCatridgeField('Seal Catridge', divert['sealCatridge'] ?? ''),
                    _buildCatridgeField('Denom', divert['denom'] ?? ''),
                    _buildCatridgeField('Bag Code', divert['bagCode'] ?? ''),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 160,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Kolom 2
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('Total', 'Rp 0'), // Total divert selalu Rp 0 sesuai permintaan
                    _buildCatridgeField('Value', divert['value']?.toString() ?? '0'),
                    _buildCatridgeField('Seal Code', divert['sealCode'] ?? ''),
                    _buildCatridgeField('Seal Code Return', divert['sealReturn'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPocketSection() {
    if (widget.pocketData == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pocket',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Layout 2 kolom untuk field pocket
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom 1
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('No. Catridge', widget.pocketData!['noCatridge'] ?? ''),
                    _buildCatridgeField('Seal Catridge', widget.pocketData!['sealCatridge'] ?? ''),
                    _buildCatridgeField('Denom', widget.pocketData!['denom'] ?? ''),
                    _buildCatridgeField('Bag Code', widget.pocketData!['bagCode'] ?? ''),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 160,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Kolom 2
              Expanded(
                child: Column(
                  children: [
                    _buildCatridgeField('Total', widget.pocketData!['total'] ?? ''),
                    _buildCatridgeField('Value', widget.pocketData!['value']?.toString() ?? '0'),
                    _buildCatridgeField('Seal Code', widget.pocketData!['sealCode'] ?? ''),
                    _buildCatridgeField('Seal Code Return', widget.pocketData!['sealReturn'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalSection() {
    int totalAmount = 0;
    String tipeDenom = widget.prepareData?.tipeDenom ?? 'A50';
    int denomAmount = tipeDenom == 'A100' ? 100000 : 50000;
    
    // Calculate total from detail catridge items
    for (var item in widget.catridgeData) {
      String cleanTotal = item.total.replaceAll('Rp ', '').replaceAll('.', '').trim();
      if (cleanTotal.isNotEmpty && cleanTotal != '0') {
        try {
          totalAmount += int.parse(cleanTotal);
        } catch (e) {
          totalAmount += denomAmount * item.value;
        }
      }
    }
    
    String formattedTotal = totalAmount > 0 ? _formatCurrency(totalAmount) : 'Rp 0';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Grand Total:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            formattedTotal,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int amount) {
    return 'Rp ${amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }



  @override
  Widget build(BuildContext context) {
    final buildStartTime = DateTime.now();
    debugPrint('🎨 [BUILD] Building PrepareSummaryPage UI');
    debugPrint('⏰ [BUILD] Build start time: ${buildStartTime.toIso8601String()}');
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    debugPrint('📱 [BUILD] Screen info:');
    debugPrint('   - Screen size: ${screenSize.width}x${screenSize.height}');
    debugPrint('   - Device pixel ratio: ${MediaQuery.of(context).devicePixelRatio}');
    debugPrint('   - Text scale factor: ${MediaQuery.of(context).textScaleFactor}');
    debugPrint('   - Platform brightness: ${MediaQuery.of(context).platformBrightness}');
    debugPrint('   - Is small screen: $isSmallScreen');
    debugPrint('   - Is submitting: $_isSubmitting');
    debugPrint('   - User name: $_userName');
    debugPrint('   - Branch name: $_branchName');
    debugPrint('   - Widget mounted: ${mounted}');
    debugPrint('   - Context hash: ${context.hashCode}');
    
    final scaffold = Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
         children: [
           _buildHeader(context, isSmallScreen),
           Expanded(child: _buildBody(context, isSmallScreen)),
         ],
       ),
    );
    
    final buildEndTime = DateTime.now();
    final buildDuration = buildEndTime.difference(buildStartTime);
    debugPrint('⏱️ [BUILD] Build completed in ${buildDuration.inMilliseconds}ms');
    debugPrint('✅ [BUILD] UI rendering finished at ${buildEndTime.toIso8601String()}');
    
    return scaffold;
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    final isTabletOrLandscapeMobile = MediaQuery.of(context).size.width >= 768;
    final isTablet = MediaQuery.of(context).size.width >= 768;
    
    return Container(
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
            'Prepare Summary',
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
              _fetchSummaryData();
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
    );
  }

  Widget _buildBody(BuildContext context, bool isSmallScreen) {
    return Container(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
            final useRow = constraints.maxWidth >= 600;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: useRow
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side - Summary Catridge Data
                        Expanded(
                          flex: 7,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Summary Data Catridge',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                // Catridge Sections
                                if (widget.catridgeData.isNotEmpty)
                                  ...widget.catridgeData.asMap().entries.map(
                                    (entry) => _buildCatridgeSection(entry.value, entry.key),
                                  ),
                                
                                // Divert Sections
                                if (widget.divertData.isNotEmpty) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Data Divert',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 16 : 18,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...widget.divertData.asMap().entries.map(
                                    (entry) => _buildDivertSection(entry.value, entry.key),
                                  ),
                                ],
                                
                                // Pocket Section
                                if (widget.pocketData != null) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Data Pocket',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isSmallScreen ? 16 : 18,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildPocketSection(),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        
                        // Right side - Detail WSID, Money Image, and Approval
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Detail WSID section
                                _buildDetailWSIDSection(isSmallScreen),
                                
                                // Divider
                                Container(
                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                
                                // Money Image section
                                _buildMoneyImageSection(isSmallScreen),
                                
                                // Divider
                                Container(
                                  margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                
                                // Approval TL Supervisor section
                                _buildApprovalSection(isSmallScreen),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // For small screens, stack vertically
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Summary Data Catridge',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 16 : 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Catridge Sections
                              if (widget.catridgeData.isNotEmpty)
                                ...widget.catridgeData.asMap().entries.map(
                                  (entry) => _buildCatridgeSection(entry.value, entry.key),
                                ),
                              
                              // Divert Sections
                              if (widget.divertData.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Data Divert',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...widget.divertData.asMap().entries.map(
                                  (entry) => _buildDivertSection(entry.value, entry.key),
                                ),
                              ],
                              
                              // Pocket Section
                              if (widget.pocketData != null) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Data Pocket',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 16 : 18,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildPocketSection(),
                              ],
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Detail WSID, Money Image, and Approval for small screens
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Detail WSID section
                              _buildDetailWSIDSection(isSmallScreen),
                              
                              // Divider
                              Container(
                                margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                height: 1,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              
                              // Money Image section
                              _buildMoneyImageSection(isSmallScreen),
                              
                              // Divider
                              Container(
                                margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                height: 1,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              
                              // Approval TL Supervisor section
                              _buildApprovalSection(isSmallScreen),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
        },
      ),
    );
  }
  


  Widget _buildDetailWSIDSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '| Detail WSID',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 15),
          
          _buildDetailRow('WSID', widget.prepareData?.atmCode ?? '-', isSmallScreen),
          _buildDetailRow('Bank', widget.prepareData?.codeBank ?? '-', isSmallScreen),
          _buildDetailRow('Lokasi', widget.prepareData?.lokasi ?? '-', isSmallScreen),
          _buildDetailRow('ATM Type', widget.prepareData?.jnsMesin ?? '-', isSmallScreen),
          _buildDetailRow('Jumlah Kaset', '${widget.prepareData?.jmlKaset ?? 0}', isSmallScreen),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoneyImageSection(bool isSmallScreen) {
    // Get tipeDenom from API data if available
    String? tipeDenom = widget.prepareData?.tipeDenom;
    
    // Convert tipeDenom to rupiah value and determine image
    String denomText = '';
    String? imagePath;
    
    // Only show denom values if prepareData is available
    if (widget.prepareData != null && tipeDenom != null) {
      if (tipeDenom == 'A50') {
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else if (tipeDenom == 'A100') {
        denomText = 'Rp 100.000';
        imagePath = 'assets/images/A100.png';
      } else if (tipeDenom == 'CDM' || tipeDenom == 'CRM') {
        // CDM/CRM always shows A50.png
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else {
        // Default fallback
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      }
    } else {
      // Empty state when no data is available
      denomText = '—';
      imagePath = null;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gambar Uang',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          denomText,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: isSmallScreen ? 80 : 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: imagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Text(
                          'Gambar tidak\nditemukan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Center(
                  child: Text(
                    'Tidak ada data\ndenominasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildApprovalSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Approval Team Leader',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tlNikController,
          decoration: const InputDecoration(
            labelText: 'NIK Team Leader',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _tlPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password Team Leader',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 45,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _validateTLAndSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSubmitting
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : Text(
                    'Submit Data Prepare',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        // Divider ATAU
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey[400])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ATAU',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey[400])),
          ],
        ),
        const SizedBox(height: 16),
        // QR Code Section
        Text(
          'Scan QR Code untuk Approval',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'TL dapat scan QR code ini untuk approval tanpa memasukkan NIK',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QRCodeGeneratorWidget(
                 action: 'PREPARE',
                 idTool: widget.prepareData?.atmCode ?? '0',
                 catridgeData: _prepareCatridgeQRData(),
               ),
            ],
          ),
        ),
      ],
    );
  }
}

// DetailCatridgeItem class if not already defined