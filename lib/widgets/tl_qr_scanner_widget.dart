// QR Scanner widget untuk TL dengan design sama seperti barcode scanner
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'dart:io';

class TLQRScannerWidget extends StatefulWidget {
  final String title;
  final Function(String) onQRDetected;
  final String? fieldKey;
  final String? fieldLabel;
  final String? sectionId;

  const TLQRScannerWidget({
    Key? key,
    required this.title,
    required this.onQRDetected,
    this.fieldKey,
    this.fieldLabel,
    this.sectionId,
  }) : super(key: key);

  @override
  State<TLQRScannerWidget> createState() => _TLQRScannerWidgetState();
}

class _TLQRScannerWidgetState extends State<TLQRScannerWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _isDisposed = false;
  StreamSubscription<Barcode>? _streamSubscription;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4CAF50), // Green color
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () async {
              await controller?.toggleFlash();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () async {
              await controller?.flipCamera();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: QRView(
                  key: qrKey,
                  onQRViewCreated: _onQRViewCreated,
                  overlay: QrScannerOverlayShape(
                    borderColor: Colors.red,
                    borderRadius: 10,
                    borderLength: 30,
                    borderWidth: 10,
                    cutOutSize: MediaQuery.of(context).size.width * 0.8,
                  ),
                  cameraFacing: CameraFacing.back,
                  formatsAllowed: const [
                    BarcodeFormat.qrcode,
                    BarcodeFormat.dataMatrix,
                    BarcodeFormat.aztec,
                    BarcodeFormat.pdf417,
                  ],
                ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF4CAF50), // Green color
              child: const Center(
                child: Text(
                  'Posisikan QR code dalam frame untuk scan otomatis\n(Generated dari Prepare Mode)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController controller) async {
    this.controller = controller;
    
    // Cancel any existing subscription
    await _streamSubscription?.cancel();
    
    // Extended delay for better camera initialization
    await Future.delayed(const Duration(milliseconds: 2500)); // Extended delay for complex QR
    
    // Configure camera settings for better QR detection
    try {
      // Set flash off initially
      await controller.toggleFlash();
      await controller.toggleFlash(); // Toggle twice to ensure it's off
      
      // Resume camera if paused
      await controller.resumeCamera();
      
      print('🔍 [QR_CAMERA] Camera configured successfully for complex QR scanning');
    } catch (e) {
      print('🔍 [QR_CAMERA] Error configuring camera: $e');
    }
    
    // Listen for scanned data with enhanced error handling
    _streamSubscription = controller.scannedDataStream.listen(
      (scanData) {
        if (!_isDisposed && mounted) {
          print('🔍 [QR_SCAN] Raw scan data received: ${scanData.code?.length ?? 0} chars');
          if (scanData.code != null && scanData.code!.isNotEmpty) {
            _handleQRCode(scanData.code!);
          } else {
            print('🔍 [QR_SCAN] Empty or null scan data received');
          }
        }
      },
      onError: (error) {
        print('🔍 [QR_SCAN] Stream error: $error');
        // Try to restart scanning on error
        if (!_isDisposed && mounted) {
          _restartScanning();
        }
      },
      onDone: () {
        print('🔍 [QR_SCAN] Stream completed');
      },
    );
    
    print('🔍 [QR_INIT] QR Scanner initialized and listening for codes');
  }

  void _handleQRCode(String code) async {
    if (_isDisposed || !mounted) {
      print('🔍 [QR_HANDLE] Scanner disposed or not mounted, ignoring QR code');
      return;
    }

    print('🔍 [QR_HANDLE] Processing QR code: ${code.length > 50 ? "${code.substring(0, 50)}..." : code}');
    print('🔍 [QR_HANDLE] QR code length: ${code.length}');
    print('🔍 [QR_HANDLE] Current state - Disposed: $_isDisposed, Mounted: $mounted');

    try {
      // Pause camera to prevent multiple scans
      await controller?.pauseCamera();
      print('🔍 [QR_HANDLE] Camera paused successfully');
    } catch (e) {
      print('🔍 [QR_HANDLE] Error pausing camera: $e');
    }

    // Execute callback if still valid
    if (!_isDisposed && mounted && widget.onQRDetected != null) {
      print('🔍 [QR_HANDLE] Executing onQRDetected callback');
      try {
        widget.onQRDetected!(code);
        print('🔍 [QR_HANDLE] Callback executed successfully');
      } catch (e) {
        print('🔍 [QR_HANDLE] Error in callback: $e');
      }
    }

    // Close scanner with delay to ensure callback completes
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!_isDisposed && mounted) {
      print('🔍 [QR_HANDLE] Closing scanner');
      try {
        Navigator.of(context).pop(code);
        print('🔍 [QR_HANDLE] Scanner closed successfully');
      } catch (e) {
        print('🔍 [QR_HANDLE] Error closing scanner: $e');
      }
    }
  }

  // Method to restart scanning when errors occur
  void _restartScanning() async {
    if (_isDisposed || !mounted) return;
    
    print('🔍 [QR_RESTART] Restarting QR scanning...');
    
    try {
      // Cancel current subscription
      await _streamSubscription?.cancel();
      
      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Resume camera
      await controller?.resumeCamera();
      
      // Restart listening
      if (controller != null && !_isDisposed && mounted) {
        _streamSubscription = controller!.scannedDataStream.listen(
          (scanData) {
            if (!_isDisposed && mounted) {
              print('🔍 [QR_RESTART] Scan data received after restart: ${scanData.code?.length ?? 0} chars');
              if (scanData.code != null && scanData.code!.isNotEmpty) {
                _handleQRCode(scanData.code!);
              }
            }
          },
          onError: (error) {
            print('🔍 [QR_RESTART] Stream error after restart: $error');
          },
        );
        
        print('🔍 [QR_RESTART] Scanning restarted successfully');
      }
    } catch (e) {
      print('🔍 [QR_RESTART] Error restarting scanning: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _streamSubscription?.cancel();
    controller?.dispose();
    super.dispose();
  }
}
