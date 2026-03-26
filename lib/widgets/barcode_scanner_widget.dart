// RESTORED: Real barcode scanner implementation with qr_code_scanner
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'dart:io';

class BarcodeScannerWidget extends StatefulWidget {
  final String title;
  final Function(String) onBarcodeDetected;
  final String? fieldKey;
  final String? fieldLabel;
  final String? sectionId;

  const BarcodeScannerWidget({
    Key? key,
    required this.title,
    required this.onBarcodeDetected,
    this.fieldKey,
    this.fieldLabel,
    this.sectionId,
  }) : super(key: key);

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _isClosing = false;
  StreamSubscription<Barcode>? _streamSubscription;

  @override
  void reassemble() {
    super.reassemble();
    final qrController = controller;
    if (qrController == null) return;

    if (Platform.isAndroid) {
      qrController.pauseCamera();
    } else if (Platform.isIOS) {
      qrController.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF4CAF50), // Green color like total nominal
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
                cutOutSize: 300,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF4CAF50), // Green color like total nominal
              child: const Center(
                child: Text(
                  'Posisikan barcode/QR code dalam frame untuk scan otomatis',
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

  Future<void> _onQRViewCreated(QRViewController controller) async {
    await _streamSubscription?.cancel();

    final previousController = this.controller;
    if (previousController != null && !identical(previousController, controller)) {
      previousController.dispose();
    }

    this.controller = controller;
    _streamSubscription = controller.scannedDataStream.listen((scanData) {
      if (!_isProcessing && scanData.code != null && mounted) {
        _isProcessing = true;
        _handleBarcode(scanData.code!);
      }
    });
  }

  Future<void> _handleBarcode(String barcode) async {
    if (_isClosing || !mounted) return;
    _isClosing = true;

    // Vibrate and provide feedback
    // HapticFeedback.vibrate();

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await controller?.pauseCamera();

    if (!mounted) return;

    // Close the scanner first to ensure auto-close
    Navigator.of(context).pop(barcode);

    // Call the callback after navigation to prevent blocking
    Future.microtask(() {
      widget.onBarcodeDetected(barcode);
    });
  }



  @override
  void dispose() {
    _isClosing = true;
    _streamSubscription?.cancel();
    controller?.dispose();
    super.dispose();
  }
}
