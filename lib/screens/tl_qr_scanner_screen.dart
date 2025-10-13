import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';
import '../services/notification_service.dart';
import '../widgets/custom_modals.dart';
// Import qr_code_scanner_tl_widget hanya jika bukan web
import '../widgets/qr_code_scanner_tl_widget.dart' if (kIsWeb) '../widgets/qr_code_scanner_web_stub.dart';
// TESTING PHASE 1: Use only stub implementation
import '../widgets/simple_qr_scanner.dart'; // Safe QR scanner stub
import 'dart:async';

class TLQRScannerScreen extends StatefulWidget {
  const TLQRScannerScreen({Key? key}) : super(key: key);

  @override
  State<TLQRScannerScreen> createState() => _TLQRScannerScreenState();
}

class _TLQRScannerScreenState extends State<TLQRScannerScreen> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  bool _isProcessing = false;
  final List<Map<String, dynamic>> _recentScans = [];
  
  // Controllers untuk form kredensial TL
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSavingCredentials = false;

  // Variabel untuk notifikasi ke CRF_OPR
  String? _operatorId;
  String? _operatorName;
  
  // Timeout untuk scanner
  Timer? _scannerTimeoutTimer;
  
  // Flag untuk memilih scanner yang digunakan
  bool _useAlternativeScanner = true; // Set ke true untuk menggunakan scanner alternatif

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CRF_TL
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Cek kredensial TL yang tersimpan
    _checkSavedCredentials();
    
    // Check if we have a QR result passed from tl_home_page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ModalRoute.of(context)?.settings.arguments != null) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
        final qrResult = args?['qrResult'] as String?;
        
        if (qrResult != null && qrResult.isNotEmpty) {
          debugPrint('Received QR result from home page: ${qrResult.length > 20 ? "${qrResult.substring(0, 20)}..." : qrResult}');
          _processQRCodeFromArgs(qrResult);
        }
      }
    });
  }
  
  @override
  void dispose() {
    _nikController.dispose();
    _passwordController.dispose();
    _scannerTimeoutTimer?.cancel();
    super.dispose();
  }
  
  // Cek kredensial TL yang tersimpan
  Future<void> _checkSavedCredentials() async {
    final credentials = await _authService.getTLSPVCredentials();
    if (credentials != null) {
      print('Found saved TL credentials: username=${credentials['username']}');
    } else {
      print('No saved TL credentials found');
    }
  }
  
  // Simpan kredensial TL
  Future<void> _saveCredentials() async {
    if (_nikController.text.isEmpty || _passwordController.text.isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'NIK dan Password harus diisi',
      );
      return;
    }
    
    setState(() {
      _isSavingCredentials = true;
    });
    
    try {
      final success = await _authService.saveTLSPVCredentials(
        _nikController.text.trim(),
        _passwordController.text.trim()
      );
      
      if (success) {
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Kredensial TL berhasil disimpan',
        );
        
        // Clear form
        _nikController.clear();
        _passwordController.clear();
      } else {
        await CustomModals.showFailedModal(
          context: context,
          message: 'Gagal menyimpan kredensial TL',
        );
      }
    } catch (e) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isSavingCredentials = false;
      });
    }
  }

  Future<void> _processQRCode(String qrCode) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      String action = '';
      String idTool = '';
      int timestamp = 0;
      List<CatridgeQRData>? catridgeData;
      
      // PENTING: Log QR code awal untuk debugging
      print('Processing QR Code: ${qrCode.length > 50 ? "${qrCode.substring(0, 50)}..." : qrCode}');
      print('QR Code length: ${qrCode.length}');
      
      // PERBAIKAN: Coba berbagai metode untuk mendeteksi format QR
      
      // 1. Coba format terenkripsi (base64)
      bool isEncrypted = false;
      bool isValidJson = false;
      bool isDelimitedFormat = false;
      Map<String, dynamic>? jsonData;
      
      // Coba decode base64
      try {
        base64Decode(qrCode);
        isEncrypted = true;
        print('QR appears to be valid base64');
      } catch (e) {
        isEncrypted = false;
        print('QR is not valid base64: $e');
      }
      
      // Jika bukan base64, coba parse sebagai JSON langsung
      if (!isEncrypted) {
        try {
          jsonData = json.decode(qrCode) as Map<String, dynamic>;
          isValidJson = true;
          print('QR is valid JSON: ${jsonData.keys.toList()}');
        } catch (e) {
          isValidJson = false;
          print('QR is not valid JSON: $e');
        }
      }
      
      // Jika bukan JSON, coba format dengan delimiter |
      if (!isEncrypted && !isValidJson) {
        final parts = qrCode.split('|');
        if (parts.length >= 3) {
          isDelimitedFormat = true;
          print('QR appears to be using delimiter format with ${parts.length} parts');
        }
      }
      
      // Proses berdasarkan format yang terdeteksi
      if (isEncrypted) {
        // Format terenkripsi dengan base64
        print('Processing encrypted QR format');
        
        // Dekripsi data QR
        final decryptedData = _authService.decryptDataFromQR(qrCode);
        print('Decryption result: ${decryptedData != null ? "SUCCESS" : "FAILED"}');
        
        if (decryptedData == null) {
          throw Exception('QR Code tidak valid atau sudah expired');
        }
        
        // Log semua keys untuk debugging
        print('Decrypted data keys: ${decryptedData.keys.toList()}');
        
        // Ekstrak data dari QR dengan validasi yang ketat
        try {
          // Ambil action
          if (decryptedData.containsKey('action')) {
            action = decryptedData['action'].toString();
            print('Action: $action');
          } else {
            print('Missing action key in decrypted data');
            throw Exception('QR Code tidak memiliki informasi action');
          }
          
          // Ambil timestamp
          if (decryptedData.containsKey('timestamp')) {
            timestamp = int.tryParse(decryptedData['timestamp'].toString()) ?? 0;
            print('Timestamp: $timestamp');
          } else {
            print('Missing timestamp key in decrypted data');
            timestamp = 0;
          }
          
          // Cek dan ambil data catridge
          if (decryptedData.containsKey('catridges')) {
            print('QR contains catridge data');
            
            // Parse data catridge
            final catridges = decryptedData['catridges'];
            if (catridges is List) {
              catridgeData = [];
              
              for (var item in catridges) {
                if (item is Map<String, dynamic>) {
                  try {
                    final catridge = CatridgeQRData(
                      idTool: item['idTool']?.toString() ?? '0',
                      bagCode: item['bagCode'] as String,
                      catridgeCode: item['catridgeCode'] as String,
                      sealCode: item['sealCode'] as String,
                      catridgeSeal: item['catridgeSeal'] as String,
                      denomCode: item['denomCode'] as String,
                      qty: item['qty'] as String,
                      userInput: item['userInput'] as String,
                      sealReturn: item['sealReturn'] as String,
                      typeCatridgeTrx: item['typeCatridgeTrx'] as String,
                      tableCode: item['tableCode'] as String,
                      warehouseCode: item['warehouseCode'] as String,
                      operatorId: item['operatorId'] as String,
                      operatorName: item['operatorName'] as String,
                    );
                    
                    // Simpan operator ID dan name untuk notifikasi
                    _operatorId = item['operatorId'] as String;
                    _operatorName = item['operatorName'] as String;
                    
                    catridgeData.add(catridge);
                  } catch (e) {
                    print('Error parsing catridge item: $e');
                  }
                }
              }
              
              print('Parsed ${catridgeData.length} catridge items from QR');
              
              // Ambil idTool dari catridge pertama
              if (catridgeData.isNotEmpty) {
                idTool = catridgeData[0].idTool.toString();
                print('Using idTool from catridge data: $idTool');
              } else {
                throw Exception('Tidak ada data catridge yang valid dalam QR');
              }
            } else {
              throw Exception('Format data catridge tidak valid');
            }
          } else {
            // Format lama tanpa data catridge
            if (decryptedData.containsKey('idTool')) {
              idTool = decryptedData['idTool'].toString();
              print('Using idTool from QR: $idTool');
            } else {
              print('Missing idTool key in decrypted data');
              throw Exception('QR Code tidak memiliki informasi ID Tool');
            }
          }
        } catch (e) {
          print('Error processing decrypted data: $e');
          throw Exception('Format data QR tidak valid: ${e.toString()}');
        }
      } else if (isValidJson) {
        // Format JSON langsung
        print('Processing direct JSON QR format');
        
        try {
          // Ekstrak data langsung dari JSON
          if (jsonData!.containsKey('action')) {
            action = jsonData['action'].toString();
          } else {
            throw Exception('QR Code tidak memiliki informasi action');
          }
          
          if (jsonData.containsKey('idTool')) {
            idTool = jsonData['idTool'].toString();
          } else {
            throw Exception('QR Code tidak memiliki informasi ID Tool');
          }
          
          if (jsonData.containsKey('timestamp')) {
            timestamp = int.tryParse(jsonData['timestamp'].toString()) ?? 0;
      } else {
            timestamp = DateTime.now().millisecondsSinceEpoch; // Default to current time
          }
          
          // Cek dan parse data catridge jika ada
          if (jsonData.containsKey('catridges')) {
            final catridges = jsonData['catridges'];
            if (catridges is List) {
              // Proses catridges seperti pada format terenkripsi
              // ...
            }
          }
        } catch (e) {
          print('Error processing JSON data: $e');
          throw Exception('Format data JSON tidak valid: ${e.toString()}');
        }
      } else if (isDelimitedFormat) {
        // Format dengan delimiter
        print('Processing delimiter-based QR format');
        
        final parts = qrCode.split('|');
        
        if (parts.length < 3) {
          throw Exception('Format QR Code tidak valid (minimal 3 bagian)');
        }

        action = parts[0]; // PREPARE or RETURN
        idTool = parts[1];
        timestamp = int.tryParse(parts[2]) ?? 0;
        
        print('Parsed QR parts: Action=$action, IdTool=$idTool, Timestamp=$timestamp');
      } else {
        // Tidak dapat mengenali format
        throw Exception('Format QR Code tidak dikenali');
      }
      
      // Validasi timestamp
      if (timestamp == 0) {
        print('WARNING: Invalid timestamp, using current time');
        timestamp = DateTime.now().millisecondsSinceEpoch;
      }

      // Cek apakah QR code masih valid (dalam 5 menit)
      final now = DateTime.now().millisecondsSinceEpoch;
      final qrTime = timestamp;
      final diffMinutes = (now - qrTime) / (1000 * 60);

      if (diffMinutes > 5) {
        throw Exception('QR Code sudah expired (lebih dari 5 menit)');
      }

      // Ambil data user untuk TL name dan NIK
      final userData = await _authService.getUserData();
      final tlName = userData?['userName'] ?? '';
      final tlNik = userData?['userID'] ?? userData?['nik'] ?? '';
      
      // Debug log
      print('TL data: NIK=$tlNik, Name=$tlName');
      
      if (tlNik.isEmpty) {
        throw Exception('NIK TL tidak ditemukan di data login. Silakan login ulang.');
      }

      // Proses berdasarkan tipe action
      if (action.toUpperCase() == 'PREPARE') {
        if (catridgeData != null && catridgeData.isNotEmpty) {
          // Format baru: proses data catridge langsung
          await _approveAndProcessCatridges(idTool, tlNik, tlName, null, catridgeData);
        } else {
          // Format lama: hanya approve prepare
          await _approvePrepare(idTool, tlNik, tlName, false, null);
        }
      } else if (action.toUpperCase() == 'RETURN') {
        await _approveReturn(idTool, tlNik, tlName, false, null);
      } else {
        throw Exception('Tipe aksi tidak valid: $action');
      }

      // Tambahkan ke riwayat scan
      _addToRecentScans(action, idTool, true);

      // Tampilkan pesan sukses
      _showSuccessDialog(action, idTool);

    } catch (e) {
      print('ERROR processing QR: $e');
      
      // Add to recent scans as failed
      _addToRecentScans('UNKNOWN', qrCode.length > 20 ? '${qrCode.substring(0, 20)}...' : qrCode, false, error: e.toString());
      
      // Show error message
      _showErrorDialog(e.toString());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Fungsi baru untuk memproses data catridge sekaligus
  Future<void> _approveAndProcessCatridges(String idTool, String tlNik, String tlName, String? tlspvPassword, List<CatridgeQRData> catridges) async {
    try {
      print('Processing ${catridges.length} catridges for ID: $idTool by TL: $tlNik ($tlName)');
      
      // PERBAIKAN: Gunakan kredensial login CRF_TL, bukan dari QR
      final userData = await _authService.getUserData();
      final currentUser = userData?['userId'] ?? userData?['userID'] ?? userData?['nik'] ?? 'UNKNOWN';
      final currentUserName = userData?['userName'] ?? '';
      
      // Dapatkan kredensial TL dari data login, bukan dari QR
      final tlCredentials = await _authService.getTLSPVCredentials();
      
      if (tlCredentials == null || 
          !tlCredentials.containsKey('username') || 
          !tlCredentials.containsKey('password') ||
          tlCredentials['username'] == null ||
          tlCredentials['password'] == null) {
        throw Exception('Kredensial TL tidak tersedia. Silakan login kembali.');
      }
      
      final tlNikFromLogin = tlCredentials['username'].toString();
      final tlPasswordFromLogin = tlCredentials['password'].toString();
      
      print('Using TL credentials from login: $tlNikFromLogin');
      
      // Validasi nilai NIK
      if (tlNikFromLogin.isEmpty) {
        throw Exception('NIK TL tidak boleh kosong');
      }
      
      // Pastikan NIK dan password bersih dari whitespace
      final cleanNik = tlNikFromLogin.trim();
      final cleanPassword = tlPasswordFromLogin.trim();
      
      // Step 1: Validasi TL Supervisor credentials dan role - sama seperti flow manual
      print('=== STEP 1: VALIDATE TL SUPERVISOR ===');
      final validationResponse = await _apiService.validateTLSupervisor(
        nik: cleanNik,
        password: cleanPassword
      );
      
      if (!validationResponse.success || validationResponse.data?.validationStatus != 'SUCCESS') {
        throw Exception(validationResponse.message);
      }
      
      print('TLSPV validation successful: ${validationResponse.data?.userName} (${validationResponse.data?.userRole})');
      
      // Pastikan idTool valid (hilangkan spasi dan karakter non-alfanumerik)
      String cleanIdTool = idTool.trim();
      int idToolInt;
      try {
        idToolInt = int.parse(cleanIdTool);
      } catch (e) {
        throw Exception('Format ID Tool tidak valid: $cleanIdTool');
      }
      
      // Dapatkan data user saat ini untuk parameter tambahan
      final tableCode = catridges[0].tableCode; // Gunakan tableCode dari catridge pertama
      final warehouseCode = catridges[0].warehouseCode; // Gunakan warehouseCode dari catridge pertama
      
      // Step 2: Insert ATM Catridge untuk setiap item catridge
      print('=== STEP 2: INSERT ATM CATRIDGE ===');
      List<String> successMessages = [];
      List<String> errorMessages = [];
      
      for (var catridge in catridges) {
        try {
          print('Processing catridge: ${catridge.catridgeCode} (${catridge.typeCatridgeTrx})');
          
          final catridgeResponse = await _apiService.insertAtmCatridge(
            idTool: int.tryParse(catridge.idTool) ?? 0,
            bagCode: catridge.bagCode,
            catridgeCode: catridge.catridgeCode,
            sealCode: catridge.sealCode,
            catridgeSeal: catridge.catridgeSeal,
            denomCode: catridge.denomCode,
            qty: catridge.qty,
            userInput: currentUser, // Gunakan user TL sebagai userInput
            sealReturn: catridge.sealReturn,
            typeCatridgeTrx: catridge.typeCatridgeTrx,
          );
          
          if (catridgeResponse.success) {
            successMessages.add('${catridge.catridgeCode}: ${catridgeResponse.message}');
            print('Catridge ${catridge.catridgeCode} inserted successfully');
          } else {
            errorMessages.add('${catridge.catridgeCode}: ${catridgeResponse.message}');
            print('Error inserting catridge ${catridge.catridgeCode}: ${catridgeResponse.message}');
          }
        } catch (e) {
          errorMessages.add('${catridge.catridgeCode}: ${e.toString()}');
          print('Exception inserting catridge ${catridge.catridgeCode}: $e');
        }
      }
      
      // Step 3: Update Planning API - moved to last
      print('=== STEP 3: UPDATE PLANNING ===');
      print('Calling updatePlanning with: idTool=$idToolInt, cashierCode=$currentUser, spvTLCode=$cleanNik, tableCode=$tableCode');
      
      final planningResponse = await _apiService.updatePlanning(
        idTool: idToolInt,
        cashierCode: currentUser,
        spvTLCode: cleanNik,
        tableCode: tableCode,
        warehouseCode: warehouseCode,
      );
      
      if (!planningResponse.success) {
        throw Exception(planningResponse.message);
      }
      
      print('Planning update success for ID: $idTool by TL: $cleanNik ($currentUserName)');
      
      // Step 4: Kirim notifikasi ke CRF_OPR (tidak menggunakan FCM)
      if (_operatorId != null && _operatorId!.isNotEmpty) {
        print('=== STEP 4: SEND NOTIFICATION TO CRF_OPR ===');
        try {
          await _notificationService.sendNotification(
            idTool: idTool,
            action: 'PREPARE_APPROVED',
            status: 'SUCCESS',
            message: 'Prepare dengan ID: $idTool telah berhasil diapprove oleh TL: $currentUserName',
            fromUser: currentUser,
            toUser: _operatorId!,
            additionalData: {
              'successCount': successMessages.length,
              'errorCount': errorMessages.length,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
          
          print('Notification sent to CRF_OPR: $_operatorId');
        } catch (e) {
          print('Error sending notification: $e');
        }
      } else {
        print('Cannot send notification: Operator ID not available');
      }
      
      // Log hasil
      print('Catridge insertion results:');
      print('Success: ${successMessages.length}');
      print('Errors: ${errorMessages.length}');
      
      if (errorMessages.isNotEmpty) {
        print('Error messages:');
        for (var error in errorMessages) {
          print('- $error');
        }
      }
      
      // Jika ada error, tampilkan pesan warning
      if (errorMessages.isNotEmpty) {
        _showWarningDialog(
          'Sebagian Catridge Gagal',
          'Berhasil: ${successMessages.length}, Gagal: ${errorMessages.length}\n\nDetail error:\n${errorMessages.join('\n')}'
        );
      }
    } catch (e) {
      print('Error processing catridges: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> _approvePrepare(String idTool, String tlNik, String tlName, bool bypassNikValidation, String? tlspvPassword) async {
    try {
      print('Approving prepare for ID: $idTool by TL: $tlNik ($tlName), bypassValidation: $bypassNikValidation, hasPassword: ${tlspvPassword != null}');
      
      // PERBAIKAN: Gunakan kredensial login CRF_TL, bukan dari QR
      final userData = await _authService.getUserData();
      final currentUser = userData?['nik'] ?? userData?['userID'] ?? 'UNKNOWN';
      final currentUserName = userData?['userName'] ?? '';
      
      // Dapatkan kredensial TL dari data login, bukan dari QR
      final tlCredentials = await _authService.getTLSPVCredentials();
      
      if (tlCredentials == null || 
          !tlCredentials.containsKey('username') || 
          !tlCredentials.containsKey('password') ||
          tlCredentials['username'] == null ||
          tlCredentials['password'] == null) {
        throw Exception('Kredensial TL tidak tersedia. Silakan login kembali.');
      }
      
      final tlNikFromLogin = tlCredentials['username'].toString();
      final tlPasswordFromLogin = tlCredentials['password'].toString();
      
      print('Using TL credentials from login: $tlNikFromLogin');
      
      // Validasi nilai NIK
      if (tlNikFromLogin.isEmpty) {
        throw Exception('NIK TL tidak boleh kosong');
      }
      
      // Pastikan NIK dan password bersih dari whitespace
      final cleanNik = tlNikFromLogin.trim();
      final cleanPassword = tlPasswordFromLogin.trim();
      
      // Step 1: Validasi TL Supervisor credentials dan role - sama seperti flow manual
      print('=== STEP 1: VALIDATE TL SUPERVISOR ===');
        final validationResponse = await _apiService.validateTLSupervisor(
        nik: cleanNik,
        password: cleanPassword
        );
        
      if (!validationResponse.success || validationResponse.data?.validationStatus != 'SUCCESS') {
          throw Exception(validationResponse.message);
        }
        
      print('TLSPV validation successful: ${validationResponse.data?.userName} (${validationResponse.data?.userRole})');
      
      // Pastikan idTool valid (hilangkan spasi dan karakter non-alfanumerik)
      String cleanIdTool = idTool.trim();
      int idToolInt;
      try {
        idToolInt = int.parse(cleanIdTool);
      } catch (e) {
        throw Exception('Format ID Tool tidak valid: $cleanIdTool');
      }
      
      // Dapatkan data user saat ini untuk parameter tambahan
      final tableCode = userData?['tableCode'] ?? 'DEFAULT';
      final warehouseCode = userData?['warehouseCode'] ?? 'Cideng';
      
      // Step 2: Update Planning API - sama seperti flow manual
      print('=== STEP 2: UPDATE PLANNING ===');
      print('Calling updatePlanning with: idTool=$idToolInt, cashierCode=$currentUser, spvTLCode=$cleanNik, tableCode=$tableCode');
      
      final planningResponse = await _apiService.updatePlanning(
        idTool: idToolInt,
        cashierCode: currentUser,
        spvTLCode: cleanNik,
        tableCode: tableCode,
        warehouseCode: warehouseCode,
      );
      
      if (!planningResponse.success) {
        throw Exception(planningResponse.message);
      }
      
      print('Planning update success for ID: $idTool by TL: $cleanNik ($currentUserName)');
      
      // Kirim notifikasi ke CRF_OPR jika ada informasi operator
      if (_operatorId != null && _operatorId!.isNotEmpty) {
        try {
          await _notificationService.sendNotification(
            idTool: idTool,
            action: 'PREPARE_APPROVED',
            status: 'SUCCESS',
            message: 'Prepare dengan ID: $idTool telah berhasil diapprove oleh TL: $currentUserName',
            fromUser: currentUser,
            toUser: _operatorId!,
            additionalData: null,
          );
          
          print('Notification sent to CRF_OPR: $_operatorId');
        } catch (e) {
          print('Error sending notification: $e');
        }
      }
    } catch (e) {
      print('Error approving prepare: $e');
      throw Exception(e.toString());
    }
  }

  Future<void> _approveReturn(String idTool, String tlNik, String tlName, bool bypassNikValidation, String? tlspvPassword) async {
    try {
      print('Approving return for ID: $idTool by TL: $tlNik ($tlName), bypassValidation: $bypassNikValidation, hasPassword: ${tlspvPassword != null}');
      
      // PERBAIKAN: Gunakan kredensial login CRF_TL, bukan dari QR
      final userData = await _authService.getUserData();
      final currentUser = userData?['nik'] ?? userData?['userID'] ?? 'UNKNOWN';
      final currentUserName = userData?['userName'] ?? '';
      
      // Dapatkan kredensial TL dari data login, bukan dari QR
      final tlCredentials = await _authService.getTLSPVCredentials();
      
      if (tlCredentials == null || 
          !tlCredentials.containsKey('username') || 
          !tlCredentials.containsKey('password') ||
          tlCredentials['username'] == null ||
          tlCredentials['password'] == null) {
        throw Exception('Kredensial TL tidak tersedia. Silakan login kembali.');
      }
      
      final tlNikFromLogin = tlCredentials['username'].toString();
      final tlPasswordFromLogin = tlCredentials['password'].toString();
      
      print('Using TL credentials from login: $tlNikFromLogin');
      
      // Validasi nilai NIK
      if (tlNikFromLogin.isEmpty) {
        throw Exception('NIK TL tidak boleh kosong');
      }
      
      // Pastikan NIK dan password bersih dari whitespace
      final cleanNik = tlNikFromLogin.trim();
      final cleanPassword = tlPasswordFromLogin.trim();
      
      // Step 1: Validasi TL Supervisor credentials dan role - sama seperti flow manual
      print('=== STEP 1: VALIDATE TL SUPERVISOR ===');
        final validationResponse = await _apiService.validateTLSupervisor(
        nik: cleanNik,
        password: cleanPassword
        );
        
      if (!validationResponse.success || validationResponse.data?.validationStatus != 'SUCCESS') {
          throw Exception(validationResponse.message);
        }
        
      print('TLSPV validation successful: ${validationResponse.data?.userName} (${validationResponse.data?.userRole})');
      
      // Pastikan idTool valid
      String cleanIdTool = idTool.trim();
      
      // Dapatkan data user saat ini untuk parameter tambahan
      final tableCode = userData?['tableCode'] ?? 'DEFAULT';
      final warehouseCode = userData?['warehouseCode'] ?? 'Cideng';
      
      // Step 2: Update Planning RTN - sama seperti flow manual
      print('=== STEP 2: UPDATE PLANNING RTN ===');
      final updateParams = {
        "idTool": cleanIdTool,
        "CashierReturnCode": currentUser,
        "TableReturnCode": tableCode,
        "DateStartReturn": DateTime.now().toIso8601String(),
        "WarehouseCode": warehouseCode,
        "UserATMReturn": cleanNik,
        "SPVBARusak": cleanNik,
        "IsManual": "N"
      };
      
      final updateResponse = await _apiService.updatePlanningRTN(updateParams);
      
      if (!updateResponse.success) {
        throw Exception(updateResponse.message);
      }
      
      print('Return approved for ID: $idTool by TL: $cleanNik ($currentUserName)');
      
      // Kirim notifikasi ke CRF_OPR jika ada informasi operator
      if (_operatorId != null && _operatorId!.isNotEmpty) {
        try {
          await _notificationService.sendNotification(
            idTool: idTool,
            action: 'RETURN_APPROVED',
            status: 'SUCCESS',
            message: 'Return dengan ID: $idTool telah berhasil diapprove oleh TL: $currentUserName',
            fromUser: currentUser,
            toUser: _operatorId!,
            additionalData: null,
          );
          
          print('Notification sent to CRF_OPR: $_operatorId');
        } catch (e) {
          print('Error sending notification: $e');
        }
      }
    } catch (e) {
      print('Error approving return: $e');
      throw Exception(e.toString());
    }
  }

  void _addToRecentScans(String action, String idTool, bool success, {String? error}) {
    final timestamp = DateTime.now();
    
    setState(() {
      _recentScans.insert(0, {
        'action': action,
        'idTool': idTool,
        'success': success,
        'timestamp': timestamp,
        'error': error,
      });
      
      // Keep only last 10 scans
      if (_recentScans.length > 10) {
        _recentScans.removeRange(10, _recentScans.length);
      }
    });
    
    print('Added to recent scans: Action=$action, IdTool=$idTool, Success=$success, Error=$error');
  }

  void _showSuccessDialog(String action, String idTool) async {
    await CustomModals.showSuccessModal(
      context: context,
      message: '$idTool berhasil di-approve melalui QR Code\n(${action == 'PREPARE' ? 'Prepare' : 'Return'} Approved)',
    );
  }

  void _showErrorDialog(String error) async {
    await CustomModals.showFailedModal(
      context: context,
      message: error,
    );
  }

  void _showWarningDialog(String title, String message) async {
    await CustomModals.showFailedModal(
      context: context,
      message: '$title\n\n$message',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Approve TLSPV',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0056A4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0056A4),
              Color(0xFFA9D0D7),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Kredensial TL form card
                Card(
                    elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                  ),
                    child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          const Text(
                            'TL Supervisor Credentials',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // NIK TL Field
                          TextField(
                            controller: _nikController,
                            decoration: const InputDecoration(
                              labelText: 'NIK TL',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                          ),
                        ),
                          ),
                          const SizedBox(height: 12),
                          // Password TL Field
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                        ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Save Button
                          Center(
                            child: ElevatedButton(
                              onPressed: _isSavingCredentials ? null : _saveCredentials,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                          ),
                              child: _isSavingCredentials
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Save Credentials'),
                            ),
                          ),
                        ],
                      ),
                    ),
                        ),
                        
                  const SizedBox(height: 20),
                        
                  // Scan QR Button
                  Center(
                          child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _startQRScan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                            icon: _isProcessing 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.qr_code_scanner),
                      label: Text(_isProcessing ? 'Processing...' : 'Scan QR Code'),
                            ),
                  ),
                
                  const SizedBox(height: 20),
                
                // Recent Scans Section
                  const Text(
                    'Recent Scans',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    child: _recentScans.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No recent scans',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                                itemCount: _recentScans.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final scan = _recentScans[index];
                              return ListTile(
                                leading: Icon(
                                  scan['success'] ? Icons.check_circle : Icons.error,
                                  color: scan['success'] ? Colors.green : Colors.red,
                                ),
                                title: Text(
                                  '${scan['action']} - ${scan['idTool']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: scan['error'] != null
                                    ? Text(
                                        'Error: ${scan['error']}',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      )
                                    : Text(
                                        'Success at ${_formatTimestamp(scan['timestamp'])}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontSize: 12,
                                        ),
                                      ),
                                trailing: Text(
                                  _formatTimeDiff(scan['timestamp']),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  // Process QR code received from tl_home_page
  Future<void> _processQRCodeFromArgs(String qrResult) async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      await _processQRCode(qrResult);
    } catch (e) {
      debugPrint('Error processing QR code from args: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error memproses QR code: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // PERBAIKAN: Metode untuk memulai scan QR code
  Future<void> _startQRScan() async {
    try {
      // Jika platform web, langsung tampilkan input manual
      if (kIsWeb) {
        print('🔍 Running on web platform, using manual input');
        final qrResult = await _showManualInputDialog();
        
        if (qrResult != null && qrResult.isNotEmpty) {
          print('🔍 Processing manual QR code: ${qrResult.length > 20 ? "${qrResult.substring(0, 20)}..." : qrResult}');
          
          setState(() {
            _isProcessing = true;
          });
          
          try {
            await _processQRCode(qrResult);
          } catch (e) {
            print('🔍 Error processing QR code: $e');
            await CustomModals.showFailedModal(
              context: context,
              message: 'Error memproses QR code: ${e.toString()}',
            );
          } finally {
            if (mounted) {
              setState(() {
                _isProcessing = false;
              });
            }
          }
        }
        return;
      }
      
      // Untuk platform mobile, tampilkan dialog pilihan metode scan
      final scanMethod = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Pilih Metode Scan'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Pilih metode untuk scan QR code:'),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner, size: 40),
                          onPressed: () => Navigator.of(context).pop(_useAlternativeScanner ? 'alternative' : 'scanner'),
                        ),
                        const Text('Scanner Kamera'),
                      ],
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.text_fields, size: 40),
                          onPressed: () => Navigator.of(context).pop('manual'),
                        ),
                        const Text('Input Manual'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Jika scanner normal mengalami masalah, gunakan scanner alternatif.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
                // Tampilkan switch hanya jika bukan di web platform
                if (!kIsWeb)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Scanner alternatif: '),
                      Switch(
                        value: _useAlternativeScanner,
                        activeColor: Colors.green,
                        onChanged: (value) {
                          setState(() {
                            _useAlternativeScanner = value;
                            Navigator.of(context).pop();
                            // Panggil ulang metode ini untuk menampilkan dialog dengan nilai yang diperbarui
                            _startQRScan();
                          });
                        },
                      ),
                    ],
                  ),
                if (!kIsWeb)
                  Text(
                    _useAlternativeScanner 
                      ? 'Menggunakan qr_code_scanner (lebih stabil)' 
                      : 'Menggunakan qr_mobile_vision (default)',
                    style: TextStyle(
                      fontSize: 12, 
                      color: _useAlternativeScanner ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold
                    ),
                  ),
              ],
            ),
          );
        },
      );
      
      if (scanMethod == null) {
        // User canceled
        return;
      }
      
      String? qrResult;
      
      if (scanMethod == 'scanner') {
        // Set to portrait mode before scanning
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        
        // Mulai timer untuk timeout scanner (20 detik)
        _scannerTimeoutTimer?.cancel();
        _scannerTimeoutTimer = Timer(const Duration(seconds: 20), () {
          // Jika timer habis dan scanner masih berjalan, kembali ke screen ini
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            
            // Tampilkan pesan timeout - tidak bisa await di dalam Timer callback
            Future.microtask(() async {
              await CustomModals.showFailedModal(
                context: context,
                message: 'Scanner timeout. Silakan coba lagi.',
              );
            });
          }
        });
        
        // Use the safe QR scanner widget  
        qrResult = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleQRScanner(
              title: 'Scan QR Code',
              onBarcodeDetected: (code) {
                print('🔍 QR Code detected in scanner: ${code.length > 20 ? "${code.substring(0, 20)}..." : code}');
                // Cancel timeout timer when QR code detected
                _scannerTimeoutTimer?.cancel();
              },
              fieldKey: 'qrcode',
              fieldLabel: 'Approval QR',
            ),
          ),
        );
        
        // Cancel timeout timer when returning from scanner
        _scannerTimeoutTimer?.cancel();
        
        // Reset orientation to portrait for this screen
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else if (scanMethod == 'alternative') {
        // Jika platform web, tampilkan pesan error
        if (kIsWeb) {
          await CustomModals.showFailedModal(
            context: context,
            message: 'Scanner alternatif tidak didukung di web. Gunakan input manual.',
          );
          return;
        }
        
        // Set to portrait mode before scanning
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
        
        // Mulai timer untuk timeout scanner (20 detik)
        _scannerTimeoutTimer?.cancel();
        _scannerTimeoutTimer = Timer(const Duration(seconds: 20), () {
          // Jika timer habis dan scanner masih berjalan, kembali ke screen ini
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
            
            // Tampilkan pesan timeout - tidak bisa await di dalam Timer callback
            Future.microtask(() async {
              await CustomModals.showFailedModal(
                context: context,
                message: 'Scanner timeout. Silakan coba lagi.',
              );
            });
          }
        });
        
        // Use the alternative QR scanner widget
        qrResult = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => SimpleQRScanner(
              title: 'Scan QR Code',
              onBarcodeDetected: (code) {
                print('🔍 QR Code detected in alternative scanner: ${code.length > 20 ? "${code.substring(0, 20)}..." : code}');
                // Cancel timeout timer when QR code detected
                _scannerTimeoutTimer?.cancel();
              },
              fieldKey: 'qrcode',
              fieldLabel: 'Approval QR',
            ),
          ),
        );
        
        // Cancel timeout timer when returning from scanner
        _scannerTimeoutTimer?.cancel();
        
        // Reset orientation to portrait for this screen
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else if (scanMethod == 'manual') {
        // Show manual input dialog
        qrResult = await _showManualInputDialog();
      }
      
      print('🔍 Scanner/Input closed. QR Result: ${qrResult != null ? "Found (${qrResult.length} chars)" : "NULL"}');
      
      // If QR code was scanned, process it
      if (qrResult != null && qrResult.isNotEmpty) {
        print('🔍 Processing QR code: ${qrResult.length > 20 ? "${qrResult.substring(0, 20)}..." : qrResult}');
        
        // Show loading indicator
        setState(() {
          _isProcessing = true;
        });
        
        // Process QR code in a separate try-catch
        try {
          await _processQRCode(qrResult);
        } catch (e) {
          print('🔍 Error processing QR code: $e');
          await CustomModals.showFailedModal(
            context: context,
            message: 'Error memproses QR code: ${e.toString()}',
          );
        } finally {
          // Make sure loading indicator is removed
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        }
      } else {
        print('🔍 No QR code scanned or scan was canceled');
      }
    } catch (e) {
      print('🔍 Error during QR scanning: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error scanning QR code: ${e.toString()}',
      );
      
      // Reset processing state
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  // Metode untuk menampilkan dialog input QR code manual
  Future<String?> _showManualInputDialog() async {
    final textController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Input QR Code Manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste QR code yang telah discan dengan aplikasi lain:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'Paste QR code di sini...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                if (textController.text.isNotEmpty) {
                  Navigator.of(context).pop(textController.text);
                } else {
                  await CustomModals.showFailedModal(
                    context: context,
                    message: 'QR code tidak boleh kosong',
                  );
                }
              },
              child: const Text('Proses'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  String _formatTimeDiff(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}