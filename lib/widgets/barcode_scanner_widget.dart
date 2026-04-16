// RESTORED: Real barcode scanner implementation with qr_code_scanner
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  bool _isClosing = false;
  bool _orientationEnforceScheduled = false;
  Timer? _orientationLockTimer;
  StreamSubscription<Barcode>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enforceLandscapeOrientation();
    _startOrientationLockWatchdog();
  }

  Future<void> _enforceLandscapeOrientation() async {
    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceLandscapeOrientation();
    }
  }

  @override
  void didChangeMetrics() {
    _enforceLandscapeOrientation();
  }

  void _scheduleLandscapeEnforcement() {
    if (_orientationEnforceScheduled) return;
    _orientationEnforceScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _orientationEnforceScheduled = false;
      _enforceLandscapeOrientation();
    });
  }

  void _startOrientationLockWatchdog() {
    _orientationLockTimer?.cancel();
    _orientationLockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _enforceLandscapeOrientation();
    });
  }

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
    _scheduleLandscapeEnforcement();
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
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) {
      _isProcessing = false;
      return;
    }
    _isClosing = true;

    // Vibrate and provide feedback
    // HapticFeedback.vibrate();

    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await controller?.pauseCamera();

    if (!mounted) return;

    widget.onBarcodeDetected(normalizedBarcode);

    if (!Navigator.of(context).canPop()) return;

    Navigator.of(context).pop(normalizedBarcode);
  }



  @override
  void dispose() {
    _isClosing = true;
    WidgetsBinding.instance.removeObserver(this);
    _orientationLockTimer?.cancel();
    _streamSubscription?.cancel();
    controller?.dispose();
    super.dispose();
  }
}
