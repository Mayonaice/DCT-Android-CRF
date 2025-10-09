// File stub untuk qr_code_scanner di web platform
// Berisi class dan enum yang diperlukan untuk menghindari error kompilasi

import 'package:flutter/material.dart';

// Stub untuk BarcodeFormat
enum BarcodeFormat {
  qrcode,
  aztec,
  dataMatrix,
  pdf417,
  code39,
  code93,
  code128,
  ean8,
  ean13,
}

// Stub untuk QRView
class QRView extends StatelessWidget {
  @override
  final Key? key;
  final Function(QRViewController) onQRViewCreated;
  final QrScannerOverlayShape? overlay;
  final List<BarcodeFormat>? formatsAllowed;

  const QRView({
    this.key,
    required this.onQRViewCreated,
    this.overlay,
    this.formatsAllowed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: const Center(
        child: Text('QR Scanner tidak tersedia di web'),
      ),
    );
  }
}

// Stub untuk QRViewController
class QRViewController {
  Stream<Barcode> get scannedDataStream => const Stream.empty();
  
  void dispose() {}
  void pauseCamera() {}
  void resumeCamera() {}
  Future<void> toggleFlash() async {}
  Future<void> flipCamera() async {}
}

// Stub untuk QrScannerOverlayShape
class QrScannerOverlayShape {
  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderRadius = 0,
    this.borderLength = 0,
    this.borderWidth = 0,
    this.cutOutSize = 0,
  });
}

// Stub untuk Barcode
class Barcode {
  final String? code;
  final BarcodeFormat format;

  Barcode({
    this.code,
    this.format = BarcodeFormat.qrcode,
  });
} 