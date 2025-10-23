import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import '../widgets/custom_modals.dart';
import '../services/device_service.dart';

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
      // Get Android ID from DeviceService (same as login)
      final androidId = await DeviceService.getDeviceId();
      
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        setState(() {
          // Device name: brand + model (e.g., "Xiaomi 14", "Huawei P6 Pro")
          _deviceName = '${androidInfo.brand} ${androidInfo.model}';
          // Android version: just the version number (e.g., "14", "12", "13")
          _androidVersion = androidInfo.version.release;
          // OS version: the actual OS name (MIUI, HyperOS, etc.)
          _osVersion = _getOSVersion(androidInfo.brand, androidInfo.version.release);
          _androidId = androidId;
          _isLoading = false;
        });
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        setState(() {
          _deviceName = '${iosInfo.name} ${iosInfo.model}';
          _androidVersion = iosInfo.systemVersion;
          _osVersion = 'iOS';
          _androidId = androidId;
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

  String _getOSVersion(String brand, String androidVersion) {
    // Determine OS based on brand and Android version
    final brandLower = brand.toLowerCase();
    debugPrint('🔍 Detecting OS for brand: $brand, Android version: $androidVersion');
    
    switch (brandLower) {
      case 'xiaomi':
      case 'redmi':
      case 'poco':
        // Xiaomi uses MIUI or HyperOS
        int version = int.tryParse(androidVersion) ?? 0;
        if (version >= 14) {
          return 'HyperOS';
        } else {
          return 'MIUI';
        }
      case 'huawei':
        return 'EMUI';
      case 'honor':
        return 'Magic UI';
      case 'oppo':
        return 'ColorOS';
      case 'vivo':
        return 'Funtouch OS';
      case 'realme':
        return 'Realme UI';
      case 'oneplus':
        return 'OxygenOS';
      case 'samsung':
        return 'One UI';
      case 'google':
      case 'pixel':
        return 'Stock Android';
      case 'motorola':
        return 'My UX';
      case 'sony':
        return 'Xperia UI';
      case 'lg':
        return 'LG UX';
      case 'htc':
        return 'HTC Sense';
      case 'asus':
        return 'ZenUI';
      case 'nokia':
        return 'Android One';
      default:
        // Fallback: try to detect from system properties or use generic Android
        debugPrint('⚠️ Unknown brand: $brand, using Android as fallback');
        return 'Android';
    }
  }

  void _copyAndroidId() {
    Clipboard.setData(ClipboardData(text: _androidId));
    CustomModals.showSuccessModal(
      context: context,
      message: 'Android ID berhasil disalin ke clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header putih dengan tombol back merah dan title "Device Info"
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: Colors.white,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Device Info',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Konten scrollable mengikuti layout tl_profile_screen.dart
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: _isLoading 
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PhoneIcon.png dengan ukuran besar di tengah-tengah dibawah header
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 32),
                            child: Image.asset(
                              'assets/images/PhoneIcon.png',
                              width: 260,
                              height: 260,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),

                        // Nama Device (menggantikan userName)
                        const Text(
                          'Nama Device',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 2, width: 180, color: Colors.black87),

                        const SizedBox(height: 12),

                        Text(
                          _deviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Android Version label
                        const Text(
                          'Android Version',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 2, width: 220, color: Colors.black54),

                        const SizedBox(height: 12),

                        // Android version value
                        Text(
                          _androidVersion,
                          style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 24),

                        // OS Version label
                        const Text(
                          'OS Version',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 2, width: 260, color: Colors.black54),

                        const SizedBox(height: 12),

                        // OS version value
                        Text(
                          _osVersion,
                          style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 24),

                        // Android ID label
                        const Text(
                          'Android ID',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(height: 2, width: 200, color: Colors.black54),

                        const SizedBox(height: 12),

                        // Android ID value
                        Text(
                          _androidId,
                          style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 40),

                        // Tombol Copy Android ID
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: const Color(0xFF0056A4), width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _copyAndroidId,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy, color: Color(0xFF0056A4)),
                                    SizedBox(width: 10),
                                    Text(
                                      'Copy Android ID',
                                      style: TextStyle(
                                        color: Color(0xFF0056A4),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
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
    super.dispose();
  }
}