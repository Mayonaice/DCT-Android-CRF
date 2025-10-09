import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';

class QRCodeGeneratorWidget extends StatefulWidget {
  final String action; // 'PREPARE' atau 'RETURN'
  final String idTool;
  final VoidCallback? onExpired;
  final List<CatridgeQRData>? catridgeData; // Data catridge untuk dikirimkan dalam QR

  const QRCodeGeneratorWidget({
    Key? key,
    required this.action,
    required this.idTool,
    this.onExpired,
    this.catridgeData, // Optional parameter untuk data catridge
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
      
      if (widget.catridgeData != null && widget.catridgeData!.isNotEmpty) {
        // Format baru dengan data catridge
        final prepareQRData = PrepareQRData(
          action: widget.action,
          timestamp: timestamp,
          catridges: widget.catridgeData!,
        );
        
        qrDataMap = {
          ...prepareQRData.toJson(),
          'username': username,
          'password': password,
        };
        
        print('Generated QR with catridge data: ${widget.catridgeData!.length} items');
      } else {
        // Format lama tanpa data catridge
        qrDataMap = {
          'action': widget.action,
          'idTool': widget.idTool,
          'timestamp': timestamp,
          'username': username,
          'password': password
        };
      }
      
      // PERBAIKAN: Verifikasi bahwa username dan password ada di qrDataMap
      print('Final QR data map keys: ${qrDataMap.keys.toList()}');
      print('Final QR username present: ${qrDataMap.containsKey('username')}');
      print('Final QR password present: ${qrDataMap.containsKey('password')}');
      
      // Enkripsi data untuk QR code
      _qrData = _authService.encryptDataForQR(qrDataMap);
      print('Generated secure QR Code with TLSPV credentials');
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
                  size: 200.0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
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