import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Use simple implementation to avoid input conflicts
import 'simple_qr_scanner.dart';
import 'custom_modals.dart';

class QRCodeScannerTLWidget extends StatefulWidget {
  final String title;
  final Function(String) onBarcodeDetected;
  final String? fieldKey;
  final String? fieldLabel;
  final String? sectionId;

  const QRCodeScannerTLWidget({
    Key? key,
    required this.title,
    required this.onBarcodeDetected,
    this.fieldKey,
    this.fieldLabel,
    this.sectionId,
  }) : super(key: key);

  @override
  State<QRCodeScannerTLWidget> createState() => _QRCodeScannerTLWidgetState();
}

class _QRCodeScannerTLWidgetState extends State<QRCodeScannerTLWidget> with WidgetsBindingObserver {
  bool _isScanning = false;
  bool _qrFound = false;
  String _scanResult = '';
  bool _hasPermission = false;
  bool _loading = true;
  Timer? _permissionCheckTimer;
  Timer? _forceRestartTimer;
  int _permissionRetryCount = 0;
  bool _forceRestarting = false;
  
  @override
  void initState() {
    super.initState();
    _isScanning = false;
    _qrFound = false;
    _hasPermission = false;
    _loading = true;
    _permissionRetryCount = 0;
    _forceRestarting = false;
    
    // Force portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    WidgetsBinding.instance.addObserver(this);
    _initializeScanner();
  }
  
  @override
  void dispose() {
    _permissionCheckTimer?.cancel();
    _forceRestartTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  Future<void> _initializeScanner() async {
    try {
      setState(() {
        _loading = false;
        _hasPermission = true;
      });
    } catch (e) {
      debugPrint('Error initializing scanner: $e');
      setState(() {
        _loading = false;
        _hasPermission = false;
      });
    }
  }

  void _onQRDetected(String qrCode) {
    if (_qrFound) return;
    
    setState(() {
      _qrFound = true;
      _scanResult = qrCode;
    });
    
    widget.onBarcodeDetected(qrCode);
    Navigator.of(context).pop(qrCode);
  }

  Future<void> _startQRScanner() async {
    if (_isScanning) return;
    
        setState(() {
      _isScanning = true;
    });
    
    try {
      final result = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => SimpleQRScanner(
            title: widget.title,
            onBarcodeDetected: _onQRDetected,
            fieldKey: widget.fieldKey,
            fieldLabel: widget.fieldLabel,
          ),
        ),
      );
      
      if (result != null && result.isNotEmpty) {
        _onQRDetected(result);
      }
    } catch (e) {
      debugPrint('Error starting QR scanner: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF0056A4),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: const Color(0xFF0056A4),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Camera permission required',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeScanner,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF0056A4),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Color(0xFF0056A4),
            ),
            const SizedBox(height: 32),
            const Text(
              'QR Scanner Ready - Tap to start scanning',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startQRScanner,
              icon: _isScanning 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.qr_code_scanner),
              label: Text(_isScanning ? 'Starting Scanner...' : 'Start QR Scanner'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0056A4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or use manual input option',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showManualInputDialog,
              child: const Text('Manual Input'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manual QR Code Input'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter or paste QR code content:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  hintText: 'Paste QR code here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  _onQRDetected(textController.text);
                  Navigator.of(context).pop();
                } else {
                  CustomModals.showFailedModal(
                    context: context,
                    message: 'QR code cannot be empty',
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }
} 