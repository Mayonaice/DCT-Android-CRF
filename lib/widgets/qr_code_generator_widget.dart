import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';

class QRCodeGeneratorWidget extends StatefulWidget {
  final String action; // 'PREPARE' atau 'RETURN'
  final String idTool;
  final VoidCallback? onExpired;
  final List<PrepareCatridgeQRData>? prepareCatridgeData; // Data catridge untuk PREPARE
  final List<ReturnCatridgeQRData>? returnCatridgeData; // Data catridge untuk RETURN
  final PrepareDetailsQRData? prepareDetails; // Details untuk PREPARE
  final ReturnDetailsQRData? returnDetails; // Details untuk RETURN

  const QRCodeGeneratorWidget({
    Key? key,
    required this.action,
    required this.idTool,
    this.onExpired,
    this.prepareCatridgeData,
    this.returnCatridgeData,
    this.prepareDetails,
    this.returnDetails,
  }) : super(key: key);

  @override
  State<QRCodeGeneratorWidget> createState() => _QRCodeGeneratorWidgetState();
}

class _QRCodeGeneratorWidgetState extends State<QRCodeGeneratorWidget> {
  late String _qrData;
  late DateTime _expiryTime;
  Timer? _timer;
  Duration _remainingTime = const Duration(minutes: 5);
  bool _isExpired = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeQRCode();
  }
  
  Future<void> _initializeQRCode() async {
    await _generateQRCode();
    _startTimer();
  }

  // Compress JSON data using gzip compression
  String _compressJsonData(Map<String, dynamic> data) {
    try {
      // Convert to JSON string
      final jsonString = json.encode(data);
      print('🗜️ [COMPRESSION] Original JSON size: ${jsonString.length} chars');
      
      // Compress using gzip
      final bytes = utf8.encode(jsonString);
      final compressed = gzip.encode(bytes);
      
      // Convert to base64 for QR code compatibility
      final compressedBase64 = base64.encode(compressed);
      print('🗜️ [COMPRESSION] Compressed size: ${compressedBase64.length} chars (${((1 - compressedBase64.length / jsonString.length) * 100).toStringAsFixed(1)}% reduction)');
      
      return compressedBase64;
    } catch (e) {
      print('❌ [COMPRESSION] Failed to compress data: $e');
      // Fallback to original JSON if compression fails
      return json.encode(data);
    }
  }

  // Decompress data (for testing purposes)
  Map<String, dynamic>? _decompressJsonData(String compressedData) {
    try {
      // Try to decode as base64 first
      final compressedBytes = base64.decode(compressedData);
      
      // Decompress using gzip
      final decompressed = gzip.decode(compressedBytes);
      final jsonString = utf8.decode(decompressed);
      
      // Parse JSON
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      print('❌ [DECOMPRESSION] Failed to decompress data: $e');
      // Try to parse as regular JSON (fallback)
      try {
        return json.decode(compressedData) as Map<String, dynamic>;
      } catch (e2) {
        print('❌ [DECOMPRESSION] Failed to parse as JSON: $e2');
        return null;
      }
    }
  }

  Future<void> _generateQRCode() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _expiryTime = DateTime.now().add(const Duration(minutes: 5));
    
    // Cek apakah ada kredensial TLSPV yang tersimpan
    final tlspvCredentials = await _authService.getTLSPVCredentials();
    
    // PERBAIKAN: Log hasil getTLSPVCredentials untuk debugging
    print('getTLSPVCredentials result: ${tlspvCredentials != null ? "NOT_NULL" : "NULL"}');
    if (tlspvCredentials != null) {
      print('Credentials keys: ${tlspvCredentials.keys.toList()}');
      print('Has username: ${tlspvCredentials.containsKey('username')}');
      print('Has password: ${tlspvCredentials.containsKey('password')}');
    }
    
    // PERBAIKAN: Coba simpan kredensial hardcoded jika tidak ada yang tersimpan
    if (tlspvCredentials == null || 
        !tlspvCredentials.containsKey('username') || 
        !tlspvCredentials.containsKey('password') ||
        tlspvCredentials['username'] == null || 
        tlspvCredentials['username'].toString().isEmpty ||
        tlspvCredentials['password'] == null || 
        tlspvCredentials['password'].toString().isEmpty) {
      
      print('No valid TLSPV credentials found, trying to save hardcoded test credentials');
      
      // Coba simpan kredensial test
      final testCredentialsSaved = await _authService.saveTLSPVCredentials('TEST_TL', 'password123');
      print('Test credentials saved: $testCredentialsSaved');
      
      // Coba ambil lagi
      final testCredentials = await _authService.getTLSPVCredentials();
      if (testCredentials != null && 
          testCredentials.containsKey('username') && 
          testCredentials['username'] != null &&
          testCredentials['username'].toString().isNotEmpty) {
        print('Successfully saved and retrieved test credentials');
      } else {
        print('Failed to save and retrieve test credentials');
      }
    }
    
    // Coba lagi mendapatkan kredensial (mungkin dari test yang baru disimpan)
    final finalCredentials = tlspvCredentials ?? await _authService.getTLSPVCredentials();
    
    if (finalCredentials != null && 
        finalCredentials.containsKey('username') && 
        finalCredentials['username'] != null && 
        finalCredentials['username'].toString().isNotEmpty &&
        finalCredentials.containsKey('password') && 
        finalCredentials['password'] != null && 
        finalCredentials['password'].toString().isNotEmpty) {
      
      // Pastikan username dan password tidak kosong
      final username = finalCredentials['username'].toString();
      final password = finalCredentials['password'].toString();
      
      print('Using TLSPV credentials for QR: username=$username');
      
      // Buat data terenkripsi yang berisi kredensial TLSPV dan data catridge
      Map<String, dynamic> qrDataMap;
      
      if (widget.action == 'PREPARE' && 
          widget.prepareCatridgeData != null && 
          widget.prepareCatridgeData!.isNotEmpty &&
          widget.prepareDetails != null) {
        // Format PREPARE dengan data catridge dan details
        final prepareQRData = PrepareQRData(
          action: widget.action,
          timestamp: timestamp,
          catridges: widget.prepareCatridgeData!,
          details: widget.prepareDetails!,
        );
        
        qrDataMap = {
          ...prepareQRData.toJson(),
          'username': username,
          'password': password,
        };
        
        print('🔧 [QR_PREPARE] Generated QR with ${widget.prepareCatridgeData!.length} catridge items and details');
        print('🔧 [QR_PREPARE] Details: WSID=${widget.prepareDetails!.wsid}, Bank=${widget.prepareDetails!.bank}');
        
      } else if (widget.action == 'RETURN' && 
                 widget.returnCatridgeData != null && 
                 widget.returnCatridgeData!.isNotEmpty &&
                 widget.returnDetails != null) {
        // Format RETURN dengan data catridge dan details
        final returnQRData = ReturnQRData(
          action: widget.action,
          timestamp: timestamp,
          catridges: widget.returnCatridgeData!,
          details: widget.returnDetails!,
        );
        
        qrDataMap = {
          ...returnQRData.toJson(),
          'username': username,
          'password': password,
        };
        
        print('🔧 [QR_RETURN] Generated QR with ${widget.returnCatridgeData!.length} catridge items and details');
        print('🔧 [QR_RETURN] Details: WSID=${widget.returnDetails!.wsid}, Bank=${widget.returnDetails!.bank}');
        
      } else {
        // Format lama tanpa data catridge (fallback)
        qrDataMap = {
          'action': widget.action,
          'idTool': widget.idTool,
          'timestamp': timestamp,
          'username': username,
          'password': password
        };
        
        print('⚠️ [QR_FALLBACK] Using fallback format - no catridge data or details provided');
      }
      
      // PERBAIKAN: Verifikasi bahwa username dan password ada di qrDataMap
      print('Final QR data map keys: ${qrDataMap.keys.toList()}');
      print('Final QR username present: ${qrDataMap.containsKey('username')}');
      print('Final QR password present: ${qrDataMap.containsKey('password')}');
      
      // IMPLEMENTASI KOMPRESI: Compress data sebelum enkripsi untuk mengurangi ukuran
      final compressedJsonData = _compressJsonData(qrDataMap);
      
      // Buat wrapper dengan flag kompresi
      final compressedDataMap = {
        'compressed': true,
        'data': compressedJsonData,
      };
      
      // Enkripsi data yang sudah dikompresi
      final encryptedData = _authService.encryptDataForQR(compressedDataMap);
      
      _qrData = encryptedData;
      print('Generated compressed & encrypted QR Code (${_qrData?.length} chars)');
      
      // Log data size untuk monitoring
      if (_qrData != null && _qrData!.length > 1000) {
        print('⚠️ [QR_SIZE] Large QR data detected (${_qrData!.length} chars) - scanner may need more time');
      }
    } else {
      // Fallback ke format lama jika tidak ada kredensial
      print('No valid credentials available, using fallback format');
      _qrData = '${widget.action}|${widget.idTool}|$timestamp|1';
      print('Generated QR Code with bypass flag (no credentials available)');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      if (now.isAfter(_expiryTime)) {
        setState(() {
          _isExpired = true;
          _remainingTime = Duration.zero;
        });
        _timer?.cancel();
        if (widget.onExpired != null) {
          widget.onExpired!();
        }
      } else {
        setState(() {
          _remainingTime = _expiryTime.difference(now);
        });
      }
    });
  }

  Future<void> _regenerateQRCode() async {
    setState(() {
      _isExpired = false;
    });
    _timer?.cancel();
    await _generateQRCode();
    _startTimer();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.qr_code,
                  color: _isExpired ? Colors.grey : Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'QR Code untuk Approve ${widget.action}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _isExpired ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // QR Code or Expired Message
            if (_isExpired) ...[
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_off,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'QR Code Expired',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Generate ulang untuk\nmembuat QR Code baru',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Active QR Code
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: _qrData,
                  version: QrVersions.auto,
                  size: 320.0, // Increased from 280.0 for better readability
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  errorCorrectionLevel: QrErrorCorrectLevel.L, // Changed to Low for maximum data capacity
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(0, 0), // No embedded image to avoid interference
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, // Square modules for better scanning
                    color: Colors.black,
                  ),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, // Square eyes for better detection
                    color: Colors.black,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Timer and Info
            if (!_isExpired) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer,
                      size: 16,
                      color: Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Expires in: ${_formatDuration(_remainingTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Info text
              Text(
                'ID Tool: ${widget.idTool}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              const SizedBox(height: 4),
              
              const Text(
                'TL dapat scan QR Code ini untuk approve tanpa input NIK & Password',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
            
            // Regenerate button
            if (_isExpired) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _regenerateQRCode,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Generate QR Code Baru'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}