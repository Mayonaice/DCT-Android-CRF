import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Face Recognition Service using FacePlusPlus API
class FaceRecognitionService {
  static const String _apiUrl = 'https://api-us.faceplusplus.com/facepp/v3/compare';
  static const String _apiKey = '0UkcKp_et_-UUOxOz_-f5ky3ViLwlXCG';
  static const String _apiSecret = 'xOYp54JMCnM0pQep-B7F_tO_BH3a6OzG';
  static const double _confidenceThreshold = 75.0;

  /// Compare two face images using FacePlusPlus API
  /// 
  /// [image1] - Direct photo/captured image (PNG format)
  /// [image2] - Scanned face image (PNG format)
  /// 
  /// Returns [FaceRecognitionResult] with match status and confidence
  static Future<FaceRecognitionResult> compareFaces({
    required Uint8List image1,
    required Uint8List image2,
  }) async {
    try {
      debugPrint('🔍 Starting face comparison with FacePlusPlus API...');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse('$_apiUrl?api_key=$_apiKey&api_secret=$_apiSecret'));
      
      // Add image files as form-data
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file1',
          image1,
          filename: 'image1.png',
        ),
      );
      
      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file2', 
          image2,
          filename: 'image2.png',
        ),
      );
      
      debugPrint('📤 Sending request to FacePlusPlus API...');
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📥 Received response with status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        debugPrint('✅ API Response received successfully');
        debugPrint('📊 Response data: ${json.encode(responseData)}');
        
        // Check if confidence field exists
        if (responseData.containsKey('confidence')) {
          final confidence = responseData['confidence'].toDouble();
          final isMatch = confidence >= _confidenceThreshold;
          
          debugPrint('🎯 Confidence: ${confidence.toStringAsFixed(2)}%');
          debugPrint('🔍 Threshold: $_confidenceThreshold%');
          debugPrint('✅ Match result: ${isMatch ? "MATCH" : "NO MATCH"}');
          
          return FaceRecognitionResult(
            isMatch: isMatch,
            confidence: confidence,
            requestId: responseData['request_id'] ?? '',
            timeUsed: responseData['time_used'] ?? 0,
            thresholds: responseData['thresholds'] ?? {},
            faces1: responseData['faces1'] ?? [],
            faces2: responseData['faces2'] ?? [],
            imageId1: responseData['image_id1'] ?? '',
            imageId2: responseData['image_id2'] ?? '',
          );
        } else {
          // Handle error response
          final errorMessage = responseData['error_message'] ?? 'Unknown error from FacePlusPlus API';
          debugPrint('❌ API Error: $errorMessage');
          
          return FaceRecognitionResult(
            isMatch: false,
            confidence: 0.0,
            error: errorMessage,
          );
        }
      } else {
        debugPrint('❌ HTTP Error: ${response.statusCode}');
        debugPrint('❌ Response body: ${response.body}');
        
        return FaceRecognitionResult(
          isMatch: false,
          confidence: 0.0,
          error: 'HTTP Error ${response.statusCode}: ${response.body}',
        );
      }
      
    } catch (e) {
      debugPrint('❌ Exception in face comparison: $e');
      return FaceRecognitionResult(
        isMatch: false,
        confidence: 0.0,
        error: 'Face comparison failed: ${e.toString()}',
      );
    }
  }

  /// Save image bytes to temporary file for debugging
  static Future<String?> _saveImageToTemp(Uint8List imageBytes, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$filename');
      await file.writeAsBytes(imageBytes);
      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving temp image: $e');
      return null;
    }
  }

  /// Validate image format (should be PNG)
  static bool _isValidPngImage(Uint8List imageBytes) {
    // Check PNG signature (first 8 bytes)
    if (imageBytes.length < 8) return false;
    
    final pngSignature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    for (int i = 0; i < 8; i++) {
      if (imageBytes[i] != pngSignature[i]) {
        return false;
      }
    }
    return true;
  }

  /// Get confidence threshold
  static double get confidenceThreshold => _confidenceThreshold;
}

/// Result of face recognition comparison
class FaceRecognitionResult {
  final bool isMatch;
  final double confidence;
  final String? error;
  final String? requestId;
  final int? timeUsed;
  final Map<String, dynamic>? thresholds;
  final List<dynamic>? faces1;
  final List<dynamic>? faces2;
  final String? imageId1;
  final String? imageId2;

  FaceRecognitionResult({
    required this.isMatch,
    required this.confidence,
    this.error,
    this.requestId,
    this.timeUsed,
    this.thresholds,
    this.faces1,
    this.faces2,
    this.imageId1,
    this.imageId2,
  });

  @override
  String toString() {
    if (error != null) {
      return 'FaceRecognitionResult(error: $error)';
    }
    return 'FaceRecognitionResult(isMatch: $isMatch, confidence: ${confidence.toStringAsFixed(2)}%, requestId: $requestId)';
  }

  /// Convert to JSON for logging/debugging
  Map<String, dynamic> toJson() {
    return {
      'isMatch': isMatch,
      'confidence': confidence,
      'error': error,
      'requestId': requestId,
      'timeUsed': timeUsed,
      'thresholds': thresholds,
      'faces1': faces1,
      'faces2': faces2,
      'imageId1': imageId1,
      'imageId2': imageId2,
    };
  }
}