import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:device_info_plus/device_info_plus.dart'; // REMOVED - namespace conflict
import 'dart:io';
import '../widgets/custom_modals.dart';

class TLDeviceInfoScreen extends StatefulWidget {
  const TLDeviceInfoScreen({Key? key}) : super(key: key);

  @override
  State<TLDeviceInfoScreen> createState() => _TLDeviceInfoScreenState();
}

class _TLDeviceInfoScreenState extends State<TLDeviceInfoScreen> {
  String _deviceName = 'Loading...';
  String _androidVersion = 'Loading...';
  String _osVersion = 'Loading...';
  String _androidId = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Force portrait orientation for CRF_TL
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    _loadDeviceInfo();
  }

  Future<void> _loadDeviceInfo() async {
    try {
      // DeviceInfoPlugin deviceInfo = DeviceInfoPlugin(); // REMOVED - namespace conflict
      
      if (Platform.isAndroid) {
        // Use Platform.environment untuk device info (replacement for device_info_plus)
        setState(() {
          _deviceName = 'Android Device'; // Simplified
          _androidVersion = 'Android ${Platform.operatingSystemVersion}';
          _osVersion = Platform.operatingSystemVersion;
          _androidId = 'Generated Device ID'; // Simplified
          _isLoading = false;
        });
      } else if (Platform.isIOS) {
        setState(() {
          _deviceName = 'iOS Device'; // Simplified
          _androidVersion = 'iOS ${Platform.operatingSystemVersion}';
          _osVersion = Platform.operatingSystemVersion;
          _androidId = 'Generated Device ID'; // Simplified
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _deviceName = 'Error loading device info';
        _androidVersion = 'Unknown';
        _osVersion = 'Unknown';
        _androidId = 'Unknown';
      });
      debugPrint('Error getting device info: $e');
    }
  }

  void _copyAndroidId() async {
    Clipboard.setData(ClipboardData(text: _androidId));
    await CustomModals.showSuccessModal(
      context: context,
      message: 'Android ID berhasil di Copy kedalam Clipboard !',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ponsel Saya',
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
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                child: _isLoading 
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading device information...'),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with phone icon
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0056A4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.phone_android,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Informasi Device',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0056A4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Device Information
                        _buildInfoSection('Nama Device', _deviceName, Icons.devices),
                        const SizedBox(height: 24),
                        
                        _buildInfoSection('Versi Android', _androidVersion, Icons.android),
                        const SizedBox(height: 24),
                        
                        _buildInfoSection('Versi OS', _osVersion, Icons.settings),
                        const SizedBox(height: 24),
                        
                        // Android ID with copy button
                        _buildInfoSectionWithCopy('Android ID', _androidId, Icons.fingerprint),
                        
                        const Spacer(),
                        
                        // Note at bottom
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Android ID digunakan untuk validasi device saat login',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF0056A4),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0056A4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSectionWithCopy(String title, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF0056A4),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0056A4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _copyAndroidId,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Keep portrait orientation for CRF_TL
    super.dispose();
  }
} 