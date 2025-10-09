// QR Scanner widget untuk TL dengan design sama seperti barcode scanner
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
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
  StreamSubscription<Barcode>? _streamSubscription;

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
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
                borderColor: const Color(0xFF4CAF50), // Green color
                borderRadius: 8,
                borderLength: 20,
                borderWidth: 6,
                cutOutSize: 250,
              ),
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

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    _streamSubscription = controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null && mounted) {
        _isProcessing = true;
        _handleQRCode(scanData.code!);
      }
    });
  }

  void _handleQRCode(String qrCode) {
    // Vibrate and provide feedback
    // HapticFeedback.vibrate();
    
    print('🔍 TL QR Scanner detected: ${qrCode.length > 50 ? "${qrCode.substring(0, 50)}..." : qrCode}');
    
    // Call the callback
    widget.onQRDetected(qrCode);
    
    // Close the scanner
    Navigator.of(context).pop(qrCode);
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    controller?.dispose();
    super.dispose();
  }
}
