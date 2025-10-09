import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../services/face_recognition.dart';
import '../services/api_service.dart';
import 'custom_modals.dart';

class FaceRecognitionWidget extends StatefulWidget {
  final String personId;
  final Function(bool success, String message) onRecognitionComplete;

  const FaceRecognitionWidget({
    Key? key,
    required this.personId,
    required this.onRecognitionComplete,
  }) : super(key: key);

  @override
  State<FaceRecognitionWidget> createState() => _FaceRecognitionWidgetState();
}

class _FaceRecognitionWidgetState extends State<FaceRecognitionWidget> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  int _countdown = 5;
  Timer? _countdownTimer;
  bool _isAutoCapture = true;
  Uint8List? _referenceImage;
  bool _isLoadingReference = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadReferenceImage();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startCountdown();
      }
    } catch (e) {
      debugPrint('❌ Error initializing camera: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal mengakses kamera',
      );
    }
  }

  Future<void> _loadReferenceImage() async {
    setState(() {
      _isLoadingReference = true;
    });

    try {
      final apiService = ApiService();
      final imageBytes = await apiService.downloadProfilePhoto(widget.personId);
      
      if (imageBytes != null) {
        setState(() {
          _referenceImage = imageBytes;
          _isLoadingReference = false;
        });
        debugPrint('✅ Reference image loaded successfully');
      } else {
        setState(() {
          _isLoadingReference = false;
        });
        await CustomModals.showFailedModal(
          context: context,
          message: 'Gagal memuat foto referensi',
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading reference image: $e');
      setState(() {
        _isLoadingReference = false;
      });
      await CustomModals.showFailedModal(
        context: context,
        message: 'Error memuat foto referensi',
      );
    }
  }

  void _startCountdown() {
    if (!_isAutoCapture) return;
    
    setState(() {
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _captureAndVerify();
      }
    });
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_referenceImage == null) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Foto referensi belum tersedia',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List capturedBytes = await imageFile.readAsBytes();

      // Compress captured image to 500KB before processing
      final compressedCapturedBytes = await _compressImage(capturedBytes);
      
      // Convert to PNG format if needed
      final pngBytes = await _convertToPng(compressedCapturedBytes);
      final referencePngBytes = await _convertToPng(_referenceImage!);

      // Compare faces using FacePlusPlus API
      final result = await FaceRecognitionService.compareFaces(
        image1: pngBytes,
        image2: referencePngBytes,
      );

      if (result.error != null) {
        // Handle API errors (non-confidence related)
        await CustomModals.showFailedModal(
          context: context,
          message: 'Oops.. sepertinya ada masalah pada server, silahkan hubungi Tim IT!',
        );
        
        // Wait 2 seconds then retry
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          _startCountdown();
        }
        return;
      }

      // Check confidence level (below 75 is considered failure)
      if (result.confidence < 75.0) {
        await CustomModals.showFailedModal(
          context: context,
          message: 'Wajah Tidak Dikenali',
        );
        
        // Wait 2 seconds then retry
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          _startCountdown();
        }
        return;
      }

      // Success case (confidence >= 75)
      await CustomModals.showSuccessModal(
        context: context,
        message: 'Verifikasi wajah berhasil!',
        onPressed: () {
          Navigator.pop(context); // Close modal
          widget.onRecognitionComplete(true, 'Face verification successful');
        },
      );

    } catch (e) {
      debugPrint('❌ Error during face verification: $e');
      await CustomModals.showFailedModal(
        context: context,
        message: 'Oops.. sepertinya ada masalah pada server, silahkan hubungi Tim IT!',
      );
      
      // Wait 2 seconds then retry
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        _startCountdown();
      }
    }
  }

  Future<Uint8List> _convertToPng(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        return Uint8List.fromList(img.encodePng(image));
      }
    } catch (e) {
      debugPrint('❌ Error converting to PNG: $e');
    }
    return imageBytes; // Return original if conversion fails
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes, {int targetSizeKB = 500}) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      // Start with quality 85 and adjust down if needed
      int quality = 85;
      Uint8List compressedBytes;
      
      do {
        compressedBytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        
        // Check if size is within target (500KB = 512000 bytes)
        if (compressedBytes.length <= targetSizeKB * 1024) {
          debugPrint('✅ Image compressed to ${compressedBytes.length} bytes with quality $quality');
          return compressedBytes;
        }
        
        // Reduce quality for next iteration
        quality -= 10;
        
      } while (quality > 20); // Don't go below 20% quality
      
      // If still too large, resize the image
      if (compressedBytes.length > targetSizeKB * 1024) {
        final resizedImage = img.copyResize(image, width: 800); // Resize to max width 800px
        compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 70));
        debugPrint('✅ Image resized and compressed to ${compressedBytes.length} bytes');
      }
      
      return compressedBytes;
    } catch (e) {
      debugPrint('❌ Error compressing image: $e');
      return imageBytes; // Return original if compression fails
    }
  }

  void _manualCapture() {
    _countdownTimer?.cancel();
    _captureAndVerify();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 80, // Increased height
          leading: IconButton(
            icon: Image.asset(
              'assets/images/back.png',
              width: 28,
              height: 28,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Konfirmasi Approve TLSPV',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: false,
        ),
      body: Column(
        children: [
          // Camera Preview Section
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isCameraInitialized && _cameraController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        children: [
                          // Camera Preview
                          Positioned.fill(
                            child: AspectRatio(
                              aspectRatio: _cameraController!.value.aspectRatio,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),
                          
                          // Face Frame Overlay
                          Positioned.fill(
                            child: CustomPaint(
                              painter: FaceFramePainter(),
                            ),
                          ),
                          
                          // Countdown or Processing Indicator
                          if (_isProcessing)
                            const Positioned.fill(
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                ),
                              ),
                            )
                          else if (_countdown > 0 && _isAutoCapture)
                            Positioned.fill(
                              child: Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_countdown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const Center(
                      child: CircularProgressIndicator(),
                    ),
            ),
          ),
          
          // Status Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                const Text(
                  'Otomatis Foto Dalam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      '${_countdown > 0 && !_isProcessing ? _countdown : 5}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'detik',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          // Verification Button - Made shorter
          Container(
            margin: const EdgeInsets.all(16),
            child: SizedBox(
              width: 200, // Fixed width instead of full width
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _manualCapture,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isProcessing ? 'Memproses...' : 'Verifikasi',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    // Calculate oval dimensions (face frame)
    final center = Offset(size.width / 2, size.height / 2);
    final ovalWidth = size.width * 0.6;
    final ovalHeight = size.height * 0.7;
    
    final rect = Rect.fromCenter(
      center: center,
      width: ovalWidth,
      height: ovalHeight,
    );

    // Draw oval frame
    canvas.drawOval(rect, paint);
    
    // Draw corner indicators
    final cornerLength = 20.0;
    final cornerPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom - cornerLength),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}